package main

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"embed"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"math/big"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/crypto/bcrypt"
)

// ---------- 配置 ----------

type Config struct {
	SecretKey     string
	DatabasePath  string
	AdminUsername string
	AdminPassword string
	Host          string
	Port          string
}

func loadConfig() *Config {
	return &Config{
		SecretKey:     envOr("SECRET_KEY", "change-this-secret-key"),
		DatabasePath:  envOr("DATABASE_PATH", "/app/data/shortlinks.db"),
		AdminUsername: envOr("ADMIN_USERNAME", "admin"),
		AdminPassword: envOr("ADMIN_PASSWORD", "admin123"),
		Host:          envOr("HOST", "0.0.0.0"),
		Port:          envOr("PORT", "5000"),
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// ---------- 模板嵌入 ----------

//go:embed templates/*.html
var templateFS embed.FS

var tmpl *template.Template

// ---------- 全局变量 ----------

var (
	db  *sql.DB
	cfg *Config
)

// ---------- 数据库 ----------

func initDB() {
	dir := filepath.Dir(cfg.DatabasePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		log.Fatalf("创建数据库目录失败: %v", err)
	}

	var err error
	db, err = sql.Open("sqlite3", cfg.DatabasePath+"?_journal_mode=WAL&_busy_timeout=5000&_synchronous=NORMAL&cache=shared")
	if err != nil {
		log.Fatalf("打开数据库失败: %v", err)
	}

	// 限制连接池以降低内存占用
	db.SetMaxOpenConns(2)
	db.SetMaxIdleConns(1)
	db.SetConnMaxLifetime(time.Hour)

	// 创建表
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS admin (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT UNIQUE NOT NULL,
			password_hash TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS shortlinks (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			key TEXT UNIQUE NOT NULL,
			url TEXT NOT NULL,
			note TEXT DEFAULT '',
			group_name TEXT DEFAULT '',
			tags TEXT DEFAULT '',
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			visits INTEGER DEFAULT 0
		)`,
		`CREATE INDEX IF NOT EXISTS idx_shortlinks_key ON shortlinks(key)`,
	}
	for _, s := range stmts {
		if _, err := db.Exec(s); err != nil {
			log.Fatalf("初始化数据库失败: %v", err)
		}
	}

	// 兼容旧数据库：检查列是否存在，不存在则添加
	migrateColumns()

	// 创建/更新管理员账户
	hash, err := bcrypt.GenerateFromPassword([]byte(cfg.AdminPassword), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("密码哈希失败: %v", err)
	}

	var count int
	db.QueryRow("SELECT COUNT(*) FROM admin WHERE username = ?", cfg.AdminUsername).Scan(&count)
	if count == 0 {
		db.Exec("INSERT INTO admin (username, password_hash) VALUES (?, ?)", cfg.AdminUsername, string(hash))
		log.Printf("创建管理员账户: %s", cfg.AdminUsername)
	} else {
		db.Exec("UPDATE admin SET password_hash = ? WHERE username = ?", string(hash), cfg.AdminUsername)
		log.Printf("更新管理员账户: %s", cfg.AdminUsername)
	}
}

func migrateColumns() {
	rows, err := db.Query("PRAGMA table_info(shortlinks)")
	if err != nil {
		return
	}
	existing := make(map[string]bool)
	for rows.Next() {
		var cid int
		var name, ctype string
		var notnull int
		var dfltValue sql.NullString
		var pk int
		rows.Scan(&cid, &name, &ctype, &notnull, &dfltValue, &pk)
		existing[name] = true
	}
	rows.Close()

	migrations := map[string]string{
		"note":       "ALTER TABLE shortlinks ADD COLUMN note TEXT DEFAULT ''",
		"group_name": "ALTER TABLE shortlinks ADD COLUMN group_name TEXT DEFAULT ''",
		"tags":       "ALTER TABLE shortlinks ADD COLUMN tags TEXT DEFAULT ''",
	}
	for col, stmt := range migrations {
		if !existing[col] {
			db.Exec(stmt)
			log.Printf("已添加 %s 列到 shortlinks 表", col)
		}
	}
}

// ---------- Session（轻量 HMAC Cookie） ----------

func signValue(value string) string {
	mac := hmac.New(sha256.New, []byte(cfg.SecretKey))
	mac.Write([]byte(value))
	sig := hex.EncodeToString(mac.Sum(nil))
	return base64.URLEncoding.EncodeToString([]byte(value + "|" + sig))
}

func verifyValue(signed string) (string, bool) {
	raw, err := base64.URLEncoding.DecodeString(signed)
	if err != nil {
		return "", false
	}
	parts := strings.SplitN(string(raw), "|", 2)
	if len(parts) != 2 {
		return "", false
	}
	mac := hmac.New(sha256.New, []byte(cfg.SecretKey))
	mac.Write([]byte(parts[0]))
	expected := hex.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(parts[1]), []byte(expected)) {
		return "", false
	}
	return parts[0], true
}

func setSession(w http.ResponseWriter, username string) {
	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    signValue(username),
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   86400,
	})
}

func getSession(r *http.Request) (string, bool) {
	c, err := r.Cookie("session")
	if err != nil {
		return "", false
	}
	return verifyValue(c.Value)
}

func clearSession(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:   "session",
		Value:  "",
		Path:   "/",
		MaxAge: -1,
	})
}

// ---------- Flash 消息 ----------

func setFlash(w http.ResponseWriter, category, message string) {
	http.SetCookie(w, &http.Cookie{
		Name:     "flash",
		Value:    signValue(category + ":" + message),
		Path:     "/",
		HttpOnly: true,
		MaxAge:   60,
	})
}

type FlashMsg struct {
	Category string
	Message  string
}

func getFlash(w http.ResponseWriter, r *http.Request) *FlashMsg {
	c, err := r.Cookie("flash")
	if err != nil {
		return nil
	}
	http.SetCookie(w, &http.Cookie{
		Name:   "flash",
		Value:  "",
		Path:   "/",
		MaxAge: -1,
	})
	val, ok := verifyValue(c.Value)
	if !ok {
		return nil
	}
	parts := strings.SplitN(val, ":", 2)
	if len(parts) != 2 {
		return nil
	}
	return &FlashMsg{Category: parts[0], Message: parts[1]}
}

// ---------- 短链生成 ----------

const shortKeyChars = "abcdefghijklmnopqrstuvwxyz0123456789"

func generateShortKey() (string, error) {
	for attempts := 0; attempts < 100; attempts++ {
		key := make([]byte, 4)
		for i := range key {
			n, err := rand.Int(rand.Reader, big.NewInt(int64(len(shortKeyChars))))
			if err != nil {
				return "", err
			}
			key[i] = shortKeyChars[n.Int64()]
		}
		k := string(key)
		var count int
		db.QueryRow("SELECT COUNT(*) FROM shortlinks WHERE key = ?", k).Scan(&count)
		if count == 0 {
			return k, nil
		}
	}
	return "", fmt.Errorf("无法生成唯一的短链key")
}

// ---------- 数据模型 ----------

type Shortlink struct {
	ID        int
	Key       string
	URL       string
	Note      string
	GroupName string
	Tags      string
	TagList   []string // 解析后的标签列表，用于模板渲染
	CreatedAt string
	Visits    int
}

// ---------- JSON 响应辅助 ----------

func jsonResponse(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

// ---------- 辅助：解析标签 ----------

func parseTags(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	var tags []string
	for _, t := range parts {
		t = strings.TrimSpace(t)
		if t != "" {
			tags = append(tags, t)
		}
	}
	return tags
}

// ---------- 辅助：智能协议检测 ----------

func getHostURL(r *http.Request) string {
	// 1. 优先使用反向代理传递的协议头
	if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
		return proto + "://" + r.Host + "/"
	}

	// 2. 如果 TLS 不为空，说明是 HTTPS
	if r.TLS != nil {
		return "https://" + r.Host + "/"
	}

	// 3. 根据 Host 判断：有端口或是 IP 地址 → HTTP，纯域名 → HTTPS
	host := r.Host
	hostOnly, port, err := net.SplitHostPort(host)
	if err == nil && port != "" {
		// 有显式端口（如 192.168.1.1:5000 或 example.com:8080）
		// 端口443视为HTTPS
		if port == "443" {
			return "https://" + host + "/"
		}
		return "http://" + host + "/"
	} else {
		hostOnly = host
	}

	// 无端口：检查是否是 IP 地址
	if ip := net.ParseIP(hostOnly); ip != nil {
		return "http://" + host + "/"
	}

	// 纯域名，默认 HTTPS
	return "https://" + host + "/"
}

// ---------- 路由处理 ----------

func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/" {
		http.Redirect(w, r, "/admin/login", http.StatusFound)
		return
	}

	key := strings.TrimPrefix(r.URL.Path, "/")
	if strings.HasPrefix(key, "admin") || key == "health" {
		http.NotFound(w, r)
		return
	}

	handleRedirectKey(w, r, key)
}

func handleRedirectKey(w http.ResponseWriter, r *http.Request, key string) {
	var url string
	err := db.QueryRow("SELECT url FROM shortlinks WHERE key = ?", key).Scan(&url)
	if err != nil {
		http.Error(w, "短链不存在", http.StatusNotFound)
		return
	}

	go func() {
		db.Exec("UPDATE shortlinks SET visits = visits + 1 WHERE key = ?", key)
	}()

	http.Redirect(w, r, url, http.StatusFound)
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		flash := getFlash(w, r)
		tmpl.ExecuteTemplate(w, "login.html", map[string]interface{}{
			"Flash": flash,
		})
		return
	}

	username := strings.TrimSpace(r.FormValue("username"))
	password := r.FormValue("password")

	var storedHash string
	err := db.QueryRow("SELECT password_hash FROM admin WHERE username = ?", username).Scan(&storedHash)
	if err != nil || bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(password)) != nil {
		setFlash(w, "error", "用户名或密码错误！")
		http.Redirect(w, r, "/admin/login", http.StatusFound)
		return
	}

	setSession(w, username)
	setFlash(w, "success", "登录成功！")
	http.Redirect(w, r, "/admin", http.StatusFound)
}

func handleLogout(w http.ResponseWriter, r *http.Request) {
	clearSession(w)
	setFlash(w, "info", "已退出登录")
	http.Redirect(w, r, "/admin/login", http.StatusFound)
}

func handleDashboard(w http.ResponseWriter, r *http.Request) {
	username, ok := getSession(r)
	if !ok {
		http.Redirect(w, r, "/admin/login", http.StatusFound)
		return
	}

	// 获取筛选参数
	filterGroup := r.URL.Query().Get("group")
	filterTag := r.URL.Query().Get("tag")

	// 构建查询
	query := "SELECT id, key, url, COALESCE(note,''), COALESCE(group_name,''), COALESCE(tags,''), created_at, visits FROM shortlinks"
	var args []interface{}
	var conditions []string

	if filterGroup != "" {
		conditions = append(conditions, "group_name = ?")
		args = append(args, filterGroup)
	}
	if filterTag != "" {
		// 模糊匹配标签（逗号分隔存储，所以用 LIKE）
		conditions = append(conditions, "(tags LIKE ? OR tags LIKE ? OR tags LIKE ? OR tags = ?)")
		args = append(args, filterTag+",%", "%,"+filterTag+",%", "%,"+filterTag, filterTag)
	}

	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}
	query += " ORDER BY created_at DESC"

	rows, err := db.Query(query, args...)
	if err != nil {
		http.Error(w, "数据库查询失败", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var links []Shortlink
	for rows.Next() {
		var l Shortlink
		rows.Scan(&l.ID, &l.Key, &l.URL, &l.Note, &l.GroupName, &l.Tags, &l.CreatedAt, &l.Visits)
		if len(l.CreatedAt) > 16 {
			l.CreatedAt = l.CreatedAt[:16]
		}
		l.TagList = parseTags(l.Tags)
		links = append(links, l)
	}

	// 获取所有分组列表（用于筛选下拉框）
	groups := getAllGroups()
	// 获取所有标签列表（用于筛选）
	allTags := getAllTags()

	flash := getFlash(w, r)
	tmpl.ExecuteTemplate(w, "dashboard.html", map[string]interface{}{
		"Username":    username,
		"Shortlinks":  links,
		"Count":       len(links),
		"Flash":       flash,
		"HostURL":     getHostURL(r),
		"Groups":      groups,
		"AllTags":     allTags,
		"FilterGroup": filterGroup,
		"FilterTag":   filterTag,
	})
}

func getAllGroups() []string {
	rows, err := db.Query("SELECT DISTINCT group_name FROM shortlinks WHERE group_name != '' ORDER BY group_name")
	if err != nil {
		return nil
	}
	defer rows.Close()
	var groups []string
	for rows.Next() {
		var g string
		rows.Scan(&g)
		groups = append(groups, g)
	}
	return groups
}

func getAllTags() []string {
	rows, err := db.Query("SELECT DISTINCT tags FROM shortlinks WHERE tags != ''")
	if err != nil {
		return nil
	}
	defer rows.Close()
	tagSet := make(map[string]bool)
	for rows.Next() {
		var raw string
		rows.Scan(&raw)
		for _, t := range parseTags(raw) {
			tagSet[t] = true
		}
	}
	var tags []string
	for t := range tagSet {
		tags = append(tags, t)
	}
	return tags
}

func handleAdd(w http.ResponseWriter, r *http.Request) {
	if _, ok := getSession(r); !ok {
		jsonResponse(w, map[string]interface{}{"success": false, "message": "未登录"})
		return
	}

	key := strings.TrimSpace(r.FormValue("key"))
	url := strings.TrimSpace(r.FormValue("url"))
	note := strings.TrimSpace(r.FormValue("note"))
	groupName := strings.TrimSpace(r.FormValue("group_name"))
	tags := strings.TrimSpace(r.FormValue("tags"))

	if url == "" {
		jsonResponse(w, map[string]interface{}{"success": false, "message": "URL不能为空"})
		return
	}

	autoGenerated := false
	if key == "" {
		var err error
		key, err = generateShortKey()
		if err != nil {
			jsonResponse(w, map[string]interface{}{"success": false, "message": err.Error()})
			return
		}
		autoGenerated = true
	}

	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		url = "https://" + url
	}

	// 规范化标签：去除多余空格
	if tags != "" {
		parts := strings.Split(tags, ",")
		var cleaned []string
		for _, t := range parts {
			t = strings.TrimSpace(t)
			if t != "" {
				cleaned = append(cleaned, t)
			}
		}
		tags = strings.Join(cleaned, ",")
	}

	_, err := db.Exec("INSERT INTO shortlinks (key, url, note, group_name, tags) VALUES (?, ?, ?, ?, ?)",
		key, url, note, groupName, tags)
	if err != nil {
		if autoGenerated {
			jsonResponse(w, map[string]interface{}{"success": false, "message": "生成短链失败，请重试"})
		} else {
			jsonResponse(w, map[string]interface{}{"success": false, "message": "该短链key已存在"})
		}
		return
	}

	if autoGenerated {
		setFlash(w, "success", fmt.Sprintf("短链添加成功！自动生成key: %s", key))
	} else {
		setFlash(w, "success", fmt.Sprintf("短链 %s 添加成功！", key))
	}
	jsonResponse(w, map[string]interface{}{"success": true, "message": "添加成功", "key": key, "auto_generated": autoGenerated})
}

func handleDelete(w http.ResponseWriter, r *http.Request) {
	if _, ok := getSession(r); !ok {
		jsonResponse(w, map[string]interface{}{"success": false, "message": "未登录"})
		return
	}

	parts := strings.Split(r.URL.Path, "/")
	if len(parts) < 4 {
		jsonResponse(w, map[string]interface{}{"success": false, "message": "无效请求"})
		return
	}
	idStr := parts[len(parts)-1]
	id, err := strconv.Atoi(idStr)
	if err != nil {
		jsonResponse(w, map[string]interface{}{"success": false, "message": "无效ID"})
		return
	}

	db.Exec("DELETE FROM shortlinks WHERE id = ?", id)
	setFlash(w, "success", "短链删除成功！")
	jsonResponse(w, map[string]interface{}{"success": true, "message": "删除成功"})
}

func handleBatchDelete(w http.ResponseWriter, r *http.Request) {
	if _, ok := getSession(r); !ok {
		jsonResponse(w, map[string]interface{}{"success": false, "message": "未登录"})
		return
	}

	var req struct {
		IDs []int `json:"ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || len(req.IDs) == 0 {
		jsonResponse(w, map[string]interface{}{"success": false, "message": "请选择要删除的短链"})
		return
	}

	tx, err := db.Begin()
	if err != nil {
		jsonResponse(w, map[string]interface{}{"success": false, "message": "数据库操作失败"})
		return
	}
	stmt, _ := tx.Prepare("DELETE FROM shortlinks WHERE id = ?")
	defer stmt.Close()

	for _, id := range req.IDs {
		stmt.Exec(id)
	}
	tx.Commit()

	setFlash(w, "success", fmt.Sprintf("已删除 %d 条短链！", len(req.IDs)))
	jsonResponse(w, map[string]interface{}{"success": true, "message": fmt.Sprintf("已删除 %d 条", len(req.IDs))})
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"healthy","database":"%s"}`, cfg.DatabasePath)
}

// ---------- 主函数 ----------

func main() {
	cfg = loadConfig()

	var err error
	tmpl, err = template.ParseFS(templateFS, "templates/*.html")
	if err != nil {
		log.Fatalf("解析模板失败: %v", err)
	}

	initDB()
	defer db.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("/admin/login", handleLogin)
	mux.HandleFunc("/admin/logout", handleLogout)
	mux.HandleFunc("/admin/add", handleAdd)
	mux.HandleFunc("/admin/delete/", handleDelete)
	mux.HandleFunc("/admin/batch-delete", handleBatchDelete)
	mux.HandleFunc("/admin", handleDashboard)
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/", handleIndex)

	addr := cfg.Host + ":" + cfg.Port
	log.Printf("启动短链服务...")
	log.Printf("管理员用户名: %s", cfg.AdminUsername)
	log.Printf("数据库路径: %s", cfg.DatabasePath)
	log.Printf("监听地址: %s", addr)

	server := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("服务启动失败: %v", err)
	}
}
