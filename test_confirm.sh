#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试确认执行函数
test_confirm_execution() {
    local script_name="测试脚本"
    echo -e "${YELLOW}即将执行: ${script_name}${NC}"
    echo -e "${CYAN}提示: 默认选择为执行(Y)，直接按回车即可执行${NC}"
    echo -e "${RED}请确认是否继续执行? (Y/n): ${NC}"
    read -r confirm
    # 默认为Y，如果用户输入n或N则取消执行
    if [[ $confirm =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}已取消执行${NC}"
        return 1
    else
        echo -e "${GREEN}确认执行!${NC}"
        return 0
    fi
}

echo "=== 测试提示信息显示 ==="
test_confirm_execution
echo "=== 测试完成 ==="