declare -A PARAMS

# 默认值
PARAMS[build_all]="false"
PARAMS[pre]="false"

# 解析 key=value 格式的参数
for arg in "$@"; do
  if [[ "$arg" == *=* ]]; then
    key="${arg%%=*}"
    value="${arg#*=}"
    PARAMS["$key"]="$value"
  else
    # 处理标志参数
    case "$arg" in
      --pre)
        PARAMS[pre]="true"
        ;;
      *)
        echo "忽略未知参数: $arg"
        ;;
    esac
  fi
done

echo "build_all: ${PARAMS[build_all]}"
echo "pre: ${PARAMS[pre]}"

build_version="5"
app_version="0.3.2"
build_all="${PARAMS[build_all]}"
build_pre="${PARAMS[pre]}"


if [ "$build_all" == 'true' ] || [ ! -d "taosync-source" ];then 
    echo "下载源码"
    zip_file="taosync.zip"
    rm -rf taosync-source
    rm -rf "taosync-${app_version}"
    wget -O "${zip_file}" "https://github.com/dr34m-cn/taosync/archive/refs/tags/v${app_version}.zip"
    unzip -q "${zip_file}"
    mv "taosync-${app_version}" taosync-source
else
    echo "已下载源码"
fi


if [ "$build_all" == 'true' ] || [ ! -d "taosync-source/front" ];then 
    # 建议使用node14
    # 检查 node 命令是否存在
    if ! command -v node &> /dev/null; then
        echo "当前环境未找到 node 命令，设置 node 环境..."
        node_ver=16
        export PATH="/var/apps/nodejs_v$node_ver/target/bin:$PATH"
        echo "已设置 node ${node_ver} 环境"
    fi
    echo "打包前端代码"    
    sed -i "s/__version_placeholder__/$app_version/g" taosync-source/frontend/src/views/page/setting/index.vue
    echo "更新前端显示版本号为: $app_version"
    cd taosync-source/frontend
    npm install && npm run build
    cd ../../
    rm -rf taosync-source/front
    mkdir -p taosync-source/front
    mv taosync-source/frontend/dist/* taosync-source/front/
    echo "前端代码编译打包完成"
else
    echo "已前编译打包前端代码"
fi


if [ "$build_all" == 'all'  ] || [ ! -d "taosync-source/wheels" ];then 
    echo "创建并激活py虚拟环境"
    cd taosync-source
    python3 -m venv .venv
    source .venv/bin/activate
    rm -rf wheels
    echo "下载离线包"
    pip download -d wheels -r requirements.txt
    cd ../
    # 下载 wheel 到本地
    echo "编译打包后端代码完成"
else
    echo "已前编译打包后端代码"
fi


echo "写入app"
app_script_path="TaoSync/app/server"
rm -rf "${app_script_path}"
# rsync -a taosync-source/  "${app_script_path}/"    
rsync -a \
    --exclude='.venv' \
    --exclude='.github' \
    --exclude='data' \
    --exclude='doc' \
    --exclude='dockerfiles' \
    --exclude='frontend' \
    --exclude='README' \
    taosync-source/  "${app_script_path}/"    
rsync update_admin.py "${app_script_path}/"


fpk_version="${app_version}-${build_version}"
if [ "$build_pre" == 'true' ];then 
    fpk_version="${fpk_version}-pre"
fi
sed -i "s|^[[:space:]]*version[[:space:]]*=.*|version=${fpk_version}|" 'TaoSync/manifest'
echo "设置构建版本号为: ${fpk_version}"

echo "开始打包 TaoSync.fpk"
# fnpack build --directory TaoSync
./fnpack.sh build --directory TaoSync


fpk_name="TaoSync-${fpk_version}.fpk"
rm -f "${fpk_name}"
mv TaoSync.fpk "${fpk_name}"
echo "打包完成: ${fpk_name}"
