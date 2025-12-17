import sys
from common import commonUtils
from common import sqlBase
from service.system import onStart


@sqlBase.connect_sql
def update_admin(conn, user_name, password):
    cursor = conn.cursor()
    passwd = commonUtils.passwd2md5(password)
    cursor.execute("update user_list set userName=?, passwd = ?", (user_name, passwd, ))
    conn.commit()
        
    
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 update_admin.py <USER_NAME> <PASSWORD>")
        sys.exit(1)
    # 初始化数据
    onStart.init()
    user_name = sys.argv[1]
    password = sys.argv[2]
    update_admin(user_name, password)