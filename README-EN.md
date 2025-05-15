# 🚀 VPSH Script Management Panel

## 📝 Introduction

VPSH is a powerful script management tool that provides a clean and attractive command-line interface for VPS server management. With this tool, you can easily execute various common scripts and system maintenance tasks without having to remember complex commands.

## ✨ Features

- 🎨 Beautiful command-line interface with colored borders and text
- 📋 Integration of 20 commonly used scripts, executable with a single command
- 🔄 Automatic adaptation to terminal window size
- 🌐 Support for script selection in different network environments (domestic/international)
- 🛠️ Includes system maintenance, network testing, panel installation, and many other functions

## 📋 Available Scripts List

| No. | Script Name | Function Description |
|------|---------|---------|
| 0 | t | Quick alias setup |
| 1 | kejilion | Kejilion one-click script |
| 2 | reinstall | System reinstallation tool (supports domestic/international sources) |
| 3 | jpso | Streaming media unlock detection |
| 4 | update | System updates and basic tool installation |
| 5 | realm | Realm deployment tool (supports domestic/international sources) |
| 6 | nezha | Nezha monitoring panel (supports domestic/international sources) |
| 7 | xui | X-UI panel installation (supports multiple versions) |
| 8 | toolbasic | Basic tools installation |
| 9 | onekey | V2Ray WSS one-click installation |
| 10 | backtrace | Backtrace tool |
| 11 | gg_test | Google connectivity test |
| 12 | key.sh | SSH key management (supports domestic/international sources) |
| 13 | jiguang | Aurora panel installation |
| 14 | NetQuality | Network quality testing |
| 15 | armnetwork | ARM network configuration |
| 16 | NodeQuality | Node quality testing |
| 17 | snell | Snell server installation |
| 18 | msdocker | 1ms Docker helper |
| 19 | indocker | Domestic Docker installation |

## 🚀 Usage

### 🔥 One-Command Installation

Use the following command to download, install, and set up the alias in one go:

```bash
wget -O ~/vpsh.sh https://raw.githubusercontent.com/tionmon/vpsh/main/vpsh.sh \
&& chmod +x ~/vpsh.sh \
&& grep -qxF "alias t='./vpsh.sh'" ~/.bashrc || echo "alias t='./vpsh.sh'" >> ~/.bashrc \
&& source ~/.bashrc
```

After execution, you can directly use the `t` command to launch the script.

#### 🔸 Command Explanation

| 🔹 Command Part | 🔹 Function Description |
|:------------|:------------|
| `wget -O ~/vpsh.sh ...` | 📥 Download the script from GitHub and save it to your home directory |
| `chmod +x ~/vpsh.sh` | 🔑 Add execution permissions to the script |
| `grep -qxF ... || echo ...` | 📝 Intelligently check and add the alias, avoiding duplicates |
| `source ~/.bashrc` | ✨ Apply the new alias settings immediately |

> 💡 **Tip**: After execution, you only need to type `t` to start the script, without entering the full path.

### 📚 Manual Installation Steps

1. Download the script:
   ```bash
   wget -O vpsh.sh https://raw.githubusercontent.com/tionmon/vpsh/main/vpsh.sh
   ```

2. Add execution permissions:
   ```bash
   chmod +x vpsh.sh
   ```

3. Run the script:
   ```bash
   ./vpsh.sh
   ```

4. Select the script number you want to execute according to the interface prompts

## 🔧 Setting an Alias

You can set an alias for quicker access to this script:

```bash
alias t='./vpsh.sh'
```

Add this line to your `~/.bashrc` file, then execute `source ~/.bashrc`. After that, you can directly use the `t` command to start the script.

## 📜 License

This project is licensed under the MIT License

## 🤝 Contribution

Issues and feature requests are welcome!