fpk_version="build-0.2"
app_version="0.3.2"
build_all=$1

if [ ! -d "taosync-source" ] || [ "$build_all" == 'all' ];then 
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


if [ ! -d "taosync-source/front" ] || [ "$build_all" == 'all' ];then 
    # 依赖node
    node_ver=16
    echo "设置node ${node_ver} 环境"
    export PATH="/var/apps/nodejs_v$node_ver/target/bin:$PATH"
    echo "打包前端代码"
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


if [ ! -d "taosync-source/wheels" ] || [ "$build_all" == 'all'  ];then 
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


build_version="${app_version}-${fpk_version}"
sed -i "s|^[[:space:]]*version[[:space:]]*=.*|version=${app_version}|" 'TaoSync/manifest'
echo "设置构建版本号为: ${build_version}"

echo "开始打包 TaoSync.fpk"
fnpack build --directory TaoSync/


fpk_name="TaoSync-${build_version}.fpk"
rm -f "${fpk_name}"
mv TaoSync.fpk "${fpk_name}"
echo "打包完成: ${fpk_name}"
