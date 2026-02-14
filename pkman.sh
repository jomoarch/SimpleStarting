#!/bin/bash
# 交互式包管理工具 - 按最近更新排序，支持模糊查找

# 检查 fzf 是否安装
if ! command -v fzf &>/dev/null; then
  echo "错误：需要 'fzf' 来进行交互选择。请安装：sudo pacman -S fzf"
  exit 1
fi

# 获取包列表，格式："日期 包名"，按日期降序（最近优先）
get_package_list() {
  # 优先使用 expac（更准确，需安装）
  if command -v expac &>/dev/null; then
    expac --timefmt='%Y-%m-%d %H:%M' '%l\t%n' | sort -r
  else
    # 备选：使用 /var/lib/pacman/local/ 目录的修改时间
    find /var/lib/pacman/local/ -maxdepth 1 -type d -name "*-*" \
      -printf "%T@ %f\n" | sort -rn | while read -r timestamp dir; do
      # 提取包名（去掉最后一个短横及之后的部分）
      pkg_name=$(echo "$dir" | sed 's/-[^-]*$//')
      # 转换时间戳为可读格式
      date_str=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null)
      echo "$date_str $pkg_name"
    done
  fi
}

# 主循环
while true; do
  # 生成列表并通过 fzf 让用户选择
  selected=$(get_package_list | fzf --prompt="选择包 > " \
    --header="最近更新/安装的包（按日期排序）" \
    --preview='echo {2} | xargs pacman -Qi 2>/dev/null' \
    --preview-window=up:5:wrap)

  # 若用户取消（未选择），退出
  [ -z "$selected" ] && echo "退出" && exit 0

  # 提取包名（第二列及之后，但日期和包名之间可能有空格，这里取最后一个字段）
  pkg=$(echo "$selected" | awk '{print $NF}')

  # 操作菜单
  echo "----------------------------------------"
  echo "已选择: $pkg"
  echo "操作: [i] 信息  [r] 卸载  [q] 返回主菜单"
  read -n 1 -p "请输入操作: " action
  echo

  case $action in
  i | I)
    pacman -Qi "$pkg"
    echo "按回车继续..."
    read -r
    ;;
  r | R)
    echo "确认卸载 $pkg ？这将删除包及其依赖（如果未在其他包使用）。"
    read -p "输入 'yes' 确认卸载: " confirm
    if [ "$confirm" = "yes" ]; then
      sudo pacman -Rns "$pkg"
      echo "卸载完成。"
    else
      echo "取消卸载。"
    fi
    echo "按回车继续..."
    read -r
    ;;
  q | Q)
    # 返回主菜单（重新循环）
    ;;
  *)
    echo "无效输入，返回主菜单。"
    ;;
  esac
done
