# โปรเจกต์ตัวอย่าง: เปลี่ยนชื่อ เตรียมไฟล์ และ deploy จริง

ตัวอย่างนี้ใช้เพียง `deploy-api.sh` และ `deploy-web.sh` ตามรูปแบบสคริปต์ Gaia ไม่มี profile เพิ่ม ให้คัดลอกโฟลเดอร์นี้ไปเป็นโปรเจกต์ใหม่ หรือคัดลอกเฉพาะสองสคริปต์ไป root ของแอปที่มีอยู่แล้ว

**Local ใช้ build image โดยไม่ต้องสร้าง `.env` หรือใส่ production env** ส่วน DB/Prisma connection และ secret key ใช้จาก Secret ใน namespace บน server ซึ่ง Deployment อ้างไว้แล้ว สคริปต์ deploy ไม่คัดลอก env จากเครื่อง local ไป server

## 1. ไฟล์ที่ต้องมี

```text
my-project/                       เปลี่ยนชื่อโฟลเดอร์เป็นชื่อโปรเจกต์จริง
├── README.md                     คู่มือนี้
├── deploy-api.sh                 สคริปต์ build/push และ deploy API
├── deploy-web.sh                 สคริปต์ build/push และ deploy Web
├── .gitignore                    กัน .env และไฟล์ที่ไม่ควร commit
├── .gitattributes                ให้ Bash scripts ใช้บรรทัดแบบ LF บน Windows
├── backend/
│   ├── Dockerfile                จำเป็น: build context คือ ./backend
│   ├── .dockerignore             กัน .env ออกจาก Docker build
│   └── app.py                    API ตัวอย่าง มี GET /health
├── frontend/
│   ├── Dockerfile                จำเป็น: build context คือ ./frontend
│   ├── .dockerignore
│   └── index.html                หน้า Web ตัวอย่าง
├── server.yaml                   ตัวอย่างทรัพยากรสำหรับติดตั้งระบบใหม่ครั้งแรก
└── tests/test_deploy.py           ตรวจสคริปต์แบบจำลอง เลือกรันเมื่อต้องการตรวจซ้ำ
```

| ไฟล์ | เมื่อใช้แอปจริง |
|---|---|
| [deploy-api.sh](deploy-api.sh), [deploy-web.sh](deploy-web.sh) | แก้ค่าด้านบนของไฟล์แล้วใช้ได้กับโครงสร้าง backend/frontend |
| [backend/Dockerfile](backend/Dockerfile), [frontend/Dockerfile](frontend/Dockerfile) | ใช้ Dockerfile ของแอปจริงที่ build context นี้ได้ |
| [backend/app.py](backend/app.py), [frontend/index.html](frontend/index.html) | เป็น source สำหรับสาธิต ให้ใช้ source ของแอปจริงแทนเมื่อนำไปใช้งาน |
| `.dockerignore` ของแต่ละฝั่ง | ต้องกัน `.env` และไฟล์ลับจาก build context |
| [server.yaml](server.yaml) | ใช้ศึกษา/ตั้งต้นเมื่อเป็นระบบใหม่ ถ้ามี Deployment/Service อยู่แล้ว ให้ใช้ manifest เดิมของระบบ |

ตัวอย่าง API เป็น Python แบบไม่ต้องติดตั้ง package และไม่เชื่อม DB สำหรับแอป Node/Prisma ให้คง `package.json`, lockfile, source และ `prisma/schema.prisma` ของแอปจริงตามที่ Dockerfile ใช้ ไม่ต้องแปลงแอปจริงเป็น Python

## 2. ชื่อตัวอย่างและค่าที่ต้องเปลี่ยน

เปิดสองสคริปต์แล้วแก้ค่าด้านบน ทุกค่า `CHANGE_ME_*` ต้องเปลี่ยนก่อนรัน คอลัมน์ตัวอย่างต่อไปนี้ใช้ชื่อสมมติ `my-project` ต้องแทนด้วยระบบจริงของบอส

| ค่าที่ค้นหา | ไฟล์ / ตัวแปรด้านบนที่ต้องแก้ | เปลี่ยนเป็นอะไร / ตัวอย่าง |
|---|---|---|
| `CHANGE_ME_REGISTRY` | ทั้งสองสคริปต์ / `REGISTRY` | hostname ไม่มี https:// และไม่มี / ท้าย เช่น `registry2.nexresearch.net` |
| `CHANGE_ME_API_IMAGE` | `deploy-api.sh` / `IMAGE` | ชื่อ image เช่น `my-project-api` |
| `CHANGE_ME_WEB_IMAGE` | `deploy-web.sh` / `IMAGE` | ชื่อ image เช่น `my-project-web` |
| `CHANGE_ME_SSH_HOST` | ทั้งสองสคริปต์ / `ATLAS_HOST` | IP/hostname ของ Kubernetes host |
| `CHANGE_ME_SSH_PORT` | ทั้งสองสคริปต์ / `ATLAS_PORT` | SSH port เช่น `22` |
| `CHANGE_ME_SSH_USER` | ทั้งสองสคริปต์ / `ATLAS_USER` | user ที่ใช้ SSH และ sudo kubectl ได้ |
| `CHANGE_ME_NAMESPACE` | ทั้งสองสคริปต์ / `NAMESPACE` | namespace จริง เช่น `my-project-prod` |
| `CHANGE_ME_API_DEPLOYMENT` | `deploy-api.sh` / `DEPLOYMENT` | เช่น `my-project-api` |
| `CHANGE_ME_WEB_DEPLOYMENT` | `deploy-web.sh` / `DEPLOYMENT` | เช่น `my-project-web` |
| `CHANGE_ME_API_CLUSTER_IP` | `deploy-api.sh` / `INTERNAL_HEALTH_URL` | ClusterIP ของ Service API |
| `CHANGE_ME_WEB_CLUSTER_IP` | `deploy-web.sh` / `EXPECTED_CLUSTER_IP` | ClusterIP ของ Service Web |
| `CHANGE_ME_API_DOMAIN` | `deploy-api.sh` / `HEALTH_URL` | domain API เช่น `api.my-project.example.com` คง `/health` ตามแอป |
| `CHANGE_ME_WEB_DOMAIN` | `deploy-web.sh` / `PRODUCTION_URL` | domain Web เช่น `my-project.example.com` |
| `CHANGE_ME_API_RUNTIME_SECRET` | `deploy-api.sh` / `RUNTIME_SECRET` | ชื่อ Secret ที่ API อ้าง เช่น `my-project-api-runtime` |

ตัวอย่าง env contract สำหรับ API จริง ให้แก้ **เฉพาะชื่อ** ใน `deploy-api.sh`:

```bash
RUNTIME_SECRET="my-project-api-runtime"
REQUIRED_SECRET_KEYS=("DATABASE_URL" "DIRECT_DATABASE_URL" "JWT_SECRET")
```

รายชื่อ key ต้องตรงกับ source/Prisma schema ของแอปจริง ไม่ใส่ connection string หรือค่า secret ลง array นี้ ตัว API สาธิตไม่มี DB จึงตั้ง `REQUIRED_SECRET_KEYS=()` ไว้ ถ้าใช้แอปจริงต้องเติมชื่อ key ที่ต้องตรวจ; array ว่างตรวจเพียงการมี Secret และการอ้าง Secret ของ Deployment

ค่าเพิ่มเติมที่ไม่มี `CHANGE_ME` แต่ต้องเทียบกับแอปจริง:

- ทั้งสองสคริปต์ / `CONTAINER="api"` หรือ `"web"`: ชื่อ container ต้องตรงกับของจริงและเป็น container ตัวแรกใน Deployment; API ตรวจชื่อนี้ก่อนเปลี่ยน image
- `deploy-api.sh` / `INTERNAL_HEALTH_URL`: เปลี่ยน port `18787` และ `/health` ถ้าแอปจริงต่างออกไป
- `deploy-api.sh` / `HEALTH_URL`: public และ internal API health ต้องตอบ HTTP 200; redirect ไม่ถือว่าผ่าน
- `deploy-web.sh` / URL `http://$EXPECTED_CLUSTER_IP:80/` ในส่วน internal smoke: เปลี่ยน port `80` หาก Service ใช้ port อื่น `PRODUCTION_URL` ไม่ใส่ `/` ท้าย
- `./backend` / `./frontend`: ถ้าเปลี่ยนชื่อโฟลเดอร์ ให้แก้ทั้ง Dockerfile preflight และ build context ในสคริปต์

ถ้าตั้งระบบใหม่ด้วย `server.yaml` ให้เปลี่ยน placeholder ที่ชื่อเหมือนกันเป็นค่าเดียวกับสคริปต์ และเปลี่ยนเพิ่ม:

| ค่าใน server.yaml | ความหมาย |
|---|---|
| `CHANGE_ME_API_IMAGE_REF` | image API จริงแบบ `registry/name@sha256:...` ที่ push แล้ว |
| `CHANGE_ME_WEB_IMAGE_REF` | image Web จริงแบบ digest ที่ push แล้ว |
| `CHANGE_ME_API_RUNTIME_SECRET` | ที่ `Deployment API → spec.template.spec.containers[0].envFrom[0].secretRef.name` ใช้ชื่อเดียวกับ `RUNTIME_SECRET` ใน `deploy-api.sh` |

ตำแหน่งใน `server.yaml` ที่ต้องแก้ให้สอดคล้องกัน:

- `Namespace.metadata.name` และ `metadata.namespace` ของ Deployment/Service ทุกตัว: namespace เดียวกับสองสคริปต์
- `Deployment.metadata.name`, `Service.metadata.name`, `spec.selector`, `template.metadata.labels`: เปลี่ยน placeholder API/Web ทุกตำแหน่งให้เป็นชื่อเดียวกัน
- `containers[].name`: ตรงกับ `CONTAINER` ของแต่ละสคริปต์
- `containers[].image`: image digest จริงของแต่ละแอป
- API `containerPort`, readiness `port`, Service `port`/`targetPort`: ตัวอย่าง `18787`; เปลี่ยนพร้อม internal health URL หาก port จริงต่างออกไป
- Web `containerPort`/readiness `port`/Service `targetPort`: ตัวอย่าง `8080`; Service `port` ตัวอย่าง `80` ตรงกับ Web internal smoke
- API readiness `path`: ตัวอย่าง `/health`; ต้องสอดคล้องกับ health endpoint ของแอป

คำว่า `Example Project` ใน `frontend/index.html` และ `example-api` ใน `backend/app.py` เป็นข้อความตัวอย่าง เปลี่ยนได้ตามชื่อแอป ไม่มีผลต่อชื่อ Deployment

## ตัวอย่างกรอกค่าจริงของ Gaia

ส่วนนี้นำค่าจาก [deploy-gaia-api.sh](../deploy-gaia-api.sh) และ [deploy-gaia-web.sh](../deploy-gaia-web.sh) ที่บอสส่งมา มาแสดงว่าต้องแทนค่าในไฟล์ตัวอย่างตรงไหน ใช้ namespace **`gaia-training`** ทั้งสองฝั่ง ค่าด้านล่างอ้างอิงสคริปต์เดิม ยังไม่ได้ยืนยันกับ server รอบนี้ โดยเฉพาะ ClusterIP ต้องตรวจว่ายังตรงกับ Service ปัจจุบัน

### A. แก้ด้านบนของ deploy-api.sh

ใน [deploy-api.sh](deploy-api.sh) ให้แทนบล็อกตั้งแต่ `REGISTRY` ถึง `HEALTH_URL` ด้วยบล็อกนี้ คงส่วนทำงานของสคริปต์ด้านล่างไว้:

```bash
REGISTRY="registry2.nexresearch.net"
IMAGE="$REGISTRY/training-event-api"

ATLAS_HOST="203.154.25.137"
ATLAS_PORT="14322"
ATLAS_USER="TUL"

NAMESPACE="gaia-training"
DEPLOYMENT="gaia-api"
CONTAINER="api"

# ต้องเปลี่ยนเป็นชื่อ Secret เดิมที่ container api อ้างบน server ตามข้อ C
RUNTIME_SECRET="CHANGE_ME_API_RUNTIME_SECRET"
# เติมเฉพาะชื่อ key ที่แอป Gaia ใช้จริง หลังเทียบ source กับ Secret เดิม
REQUIRED_SECRET_KEYS=()

INTERNAL_HEALTH_URL="http://10.43.180.116:18787/health"
HEALTH_URL="https://training-event-api.nexresearch.net/health"
```

**จุดที่ยังต้องกรอกคือ `RUNTIME_SECRET`** เพราะสคริปต์ Gaia ต้นฉบับไม่ได้ระบุชื่อ Secret จึงยังให้ชื่อจริงไม่ได้ ห้ามใช้ชื่อตัวอย่าง `my-project-api-runtime` โดยสมมติว่าเป็นของ Gaia สคริปต์ตัวอย่างจะหยุดหากยังมี `CHANGE_ME_API_RUNTIME_SECRET`

`REQUIRED_SECRET_KEYS=()` ตรวจเพียงว่า Secret มีอยู่และ Deployment อ้างชื่อนั้น ถ้าต้องการตรวจ key ให้ใส่ชื่อที่ยืนยันจากแอปจริง เช่นรูปแบบ `REQUIRED_SECRET_KEYS=("ชื่อ_key_จริง_1" "ชื่อ_key_จริง_2")` โดยไม่ใส่ค่าลับ ชื่อ `DATABASE_URL`, `DIRECT_DATABASE_URL`, `JWT_SECRET` ในคู่มือส่วนทั่วไปเป็นตัวอย่าง ยังไม่ได้ยืนยันว่าเป็นรายการที่ Gaia ใช้ครบถ้วน

### B. แก้ด้านบนของ deploy-web.sh

ใน [deploy-web.sh](deploy-web.sh) ให้แทนบล็อกตั้งแต่ `REGISTRY` ถึง `PRODUCTION_URL` ด้วย:

```bash
REGISTRY="registry2.nexresearch.net"
IMAGE="$REGISTRY/training-event-web"

ATLAS_HOST="203.154.25.137"
ATLAS_PORT="14322"
ATLAS_USER="TUL"

NAMESPACE="gaia-training"
DEPLOYMENT="gaia-web"
CONTAINER="web"
EXPECTED_CLUSTER_IP="10.43.61.231"
PRODUCTION_URL="https://training-event.nexresearch.net"
```

สรุปชื่อที่เปลี่ยนจากตัวอย่าง:

| ตำแหน่ง | ค่า Gaia |
|---|---|
| ทั้งสองไฟล์: `CHANGE_ME_REGISTRY` | `registry2.nexresearch.net` |
| ทั้งสองไฟล์: `CHANGE_ME_SSH_HOST` / `PORT` / `USER` | `203.154.25.137` / `14322` / `TUL` |
| ทั้งสองไฟล์: `CHANGE_ME_NAMESPACE` | `gaia-training` |
| API: `CHANGE_ME_API_IMAGE` / `CHANGE_ME_API_DEPLOYMENT` | `training-event-api` / `gaia-api` |
| Web: `CHANGE_ME_WEB_IMAGE` / `CHANGE_ME_WEB_DEPLOYMENT` | `training-event-web` / `gaia-web` |
| API: `CHANGE_ME_API_CLUSTER_IP` / `CHANGE_ME_API_DOMAIN` | `10.43.180.116` / `training-event-api.nexresearch.net` |
| Web: `CHANGE_ME_WEB_CLUSTER_IP` / `CHANGE_ME_WEB_DOMAIN` | `10.43.61.231` / `training-event.nexresearch.net` |
| API: `CHANGE_ME_API_RUNTIME_SECRET` | ชื่อ Secret เดิมที่อ่านได้ตามข้อ C |

### C. อ่านชื่อ Secret เดิมบน server แล้วกรอกเฉพาะชื่อ

เข้า server ด้วย SSH profile/host key ที่ยืนยันแล้ว:

```bash
ssh -t -p 14322 TUL@203.154.25.137
```

คำสั่งต่อไปนี้รัน **บน server** ตรวจ namespace, ชื่อ container และ Service ก่อน:

```bash
sudo kubectl get namespace gaia-training
sudo kubectl get deployments gaia-api gaia-web -n gaia-training
sudo kubectl get deployments gaia-api gaia-web -n gaia-training -o go-template='{{range .items}}{{.metadata.name}}{{": "}}{{range .spec.template.spec.containers}}{{.name}}{{" "}}{{end}}{{"\n"}}{{end}}'
sudo kubectl get services -n gaia-training -o wide
```

API ต้องใช้ container `api` และ Web ใช้ `web`; สำหรับสคริปต์ตัวอย่างให้ตรวจว่าเป็น container ตัวแรกด้วย เทียบ API Service กับ `10.43.180.116:18787` และ Web Service กับ `10.43.61.231:80` หากต่าง ให้แก้ค่าในข้อ A/B ตาม Service ที่ route ไปแอปนั้นจริง

อ่านชื่อ Secret และชื่อ key ที่ container `api` อ้าง โดยไม่แสดงค่า env:

```bash
sudo kubectl get deployment gaia-api -n gaia-training -o go-template='{{range .spec.template.spec.containers}}{{if eq .name "api"}}{{range .envFrom}}{{if .secretRef}}envFrom Secret={{.secretRef.name}}{{"\n"}}{{end}}{{end}}{{range .env}}{{if .valueFrom}}{{if .valueFrom.secretKeyRef}}env={{.name}} Secret={{.valueFrom.secretKeyRef.name}} key={{.valueFrom.secretKeyRef.key}}{{"\n"}}{{end}}{{end}}{{end}}{{end}}{{end}}'

# เปลี่ยนข้อความในเครื่องหมายคำพูดเป็นชื่อ Secret ที่พบด้านบน
GAIA_SECRET_NAME="CHANGE_ME_API_RUNTIME_SECRET"
sudo kubectl get secret "$GAIA_SECRET_NAME" -n gaia-training -o go-template='{{range $key, $value := .data}}{{printf "%s\n" $key}}{{end}}'
```

นำชื่อที่พบมาใส่ `RUNTIME_SECRET="ชื่อจริงที่พบ"` ใน `deploy-api.sh` และเทียบชื่อ key กับ source/Prisma schema ของ Gaia ก่อนเติม `REQUIRED_SECRET_KEYS` ตัวแปร `GAIA_SECRET_NAME` ในคำสั่งนี้เป็นเพียงชื่อทรัพยากรบน server ไม่มีค่า DB หรือ secret key และไม่ต้องตั้งบน local

ถ้า Deployment อ้างหลาย Secret ให้เลือก Secret ที่มี key ที่ต้องตรวจ; preflight ของตัวอย่างรองรับ Secret ชื่อเดียว ต้องตรวจ Secret อื่นตามที่แอปใช้อีกด้วย ถ้าคำสั่งไม่แสดงชื่อ Secret ให้ตรวจ manifest ที่ใช้อยู่ก่อน ยังสรุปไม่ได้ว่า API ได้รับ env จาก Secret แล้ว

**ไม่ต้องสร้าง `.env` ใน local ไม่ต้องคัดลอกค่าจาก Secret และไม่ต้องสร้าง Secret ใหม่** การ release เปลี่ยนเฉพาะ image และใช้ env references เดิมของ Deployment บน server การมี Secret ใน namespace ต้องมาพร้อมการอ้างใน Deployment ด้วย

### D. นำไปใช้กับ Gaia จริง

ถ้าใช้สองสคริปต์ Gaia ต้นฉบับ ค่าของข้อ A/B ถูกกรอกไว้แล้ว ให้คัดลอก [deploy-gaia-api.sh](../deploy-gaia-api.sh) และ [deploy-gaia-web.sh](../deploy-gaia-web.sh) ไป root ของ repository Gaia ตัวจริง แล้วใช้ตาม [คู่มือ Gaia หลัก](../README.md) สคริปต์ต้นฉบับคง env เดิม แต่ไม่มี preflight `RUNTIME_SECRET`/`REQUIRED_SECRET_KEYS` ที่เพิ่มในตัวอย่างนี้

ถ้าต้องการใช้สคริปต์ตัวอย่างที่มี preflight Secret ให้ทำตามนี้:

1. คัดลอกเฉพาะ `deploy-api.sh` และ `deploy-web.sh` ไป root ของ repository Gaia ที่มี `backend/` และ `frontend/` จริง
2. กรอกค่าตามข้อ A/B และชื่อ Secret ที่ยืนยันตามข้อ C
3. ใช้ source, Dockerfile, package/lockfile และ Prisma schema ของ Gaia เดิม โฟลเดอร์ `backend/`/`frontend/` ในตัวอย่างนี้เป็นแอปสาธิต ไม่ใช่ source Gaia และ `server.yaml` เป็น manifest สำหรับระบบใหม่ ไม่ใช้ทับ Deployment Gaia ที่มีอยู่
4. Commit/push สองสคริปต์ที่แก้แล้ว ให้ API อยู่ branch `main`, worktree สะอาด และ `HEAD` ตรงกับ `origin/main`
5. เปิด Bash ใน root ของ repository Gaia ตัวจริง แล้วรัน:

```bash
git status --short
git branch --show-current
git fetch origin
git rev-parse HEAD origin/main
docker login registry2.nexresearch.net
bash ./deploy-api.sh
# หรือ release Web ด้วย bash ./deploy-web.sh
```

ทั้งสองสคริปต์ build/push ก่อนถามยืนยัน ตอบ `y` จึงเปลี่ยน image บน server สคริปต์ API ตัวอย่างตรวจ Secret หลังยืนยันและก่อนเปลี่ยน image; ไม่อ่านค่า Secret มา build ใน local และไม่รัน Prisma migration

## 3. คัดลอกโฟลเดอร์เป็นโปรเจกต์ใหม่

ตัวอย่างจาก PowerShell ให้เลือก path ปลายทางใหม่ที่ยังไม่มีไฟล์:

```powershell
Copy-Item -LiteralPath D:\git\server-deploy\project-example -Destination D:\git\my-project -Recurse
Set-Location D:\git\my-project
```

ถ้าแอปมีอยู่แล้ว ให้คัดลอกเฉพาะ `deploy-api.sh` และ `deploy-web.sh` ไป root ของ repository นั้น แล้วแก้ค่าในสองไฟล์ คง Dockerfile และ source เดิมของแอปไว้

สำหรับโฟลเดอร์ที่คัดลอกเป็นโปรเจกต์ใหม่ หลังแก้ค่าในสคริปต์ครบแล้วให้เปิด Bash และสร้าง Git repository โดยแทน `YOUR_GIT_URL` ด้วย repository ที่เตรียมไว้:

```bash
cd /mnt/d/git/my-project
git init -b main
git add .
git commit -m "Initialize project and deploy scripts"
git remote add origin YOUR_GIT_URL
git push -u origin main
```

ถ้าเป็น repository เดิม ให้ commit/push การแก้สคริปต์ตาม workflow ของโปรเจกต์นั้น ไม่ต้องรัน `git init` หรือเพิ่ม origin ซ้ำ

## 4. ลอง build ใน local

เปิด Bash ที่ใช้ Docker ได้ แล้วเข้า root ของโปรเจกต์:

```bash
cd /mnt/d/git/my-project
docker build -t my-project-api:local ./backend
docker build -t my-project-web:local ./frontend
```

ตัวอย่างนี้ไม่ต้องมี `.env` หรือ database connection ในเครื่อง local Dockerfile คัดลอกเฉพาะ source ของตัวอย่าง ไม่มีการฝัง Secret ลง image

เลือกเปิด API/Web ในคนละ terminal:

```bash
docker run --rm -p 127.0.0.1:18787:18787 my-project-api:local
# อีก terminal
docker run --rm -p 127.0.0.1:8080:8080 my-project-web:local
```

เปิด `http://localhost:18787/health` จะได้ `status: ok`; เปิด `http://localhost:8080/` จะเห็นหน้า Example Project กด Ctrl+C เพื่อหยุด container

สำหรับแอปจริงที่ build ได้โดยไม่ต้องมี production env ให้ใช้แนวทางเดิมของบอส: DB/Prisma connection และ secret key อยู่บน server ขณะ runtime หาก Dockerfile ของแอปจริงมีคำสั่งที่ต้องเชื่อม DB ตอน build ต้องแยกพิจารณาคำสั่งนั้นตามแอปจริง

## 5. ตรวจสิ่งที่ต้องมีบน server

ต้องมี namespace, Deployment, Service และ public routing/TLS ที่ใช้ได้ก่อน release ผ่านสองสคริปต์นี้ Runtime env ของ API ต้องถูกอ้างโดย Deployment ผ่าน `envFrom` หรือ `env[].valueFrom` Secret/ConfigMap ใน namespace ไม่ถูกส่งให้ Pod โดยอัตโนมัติ

ตัวอย่างคำสั่งบน server หลังเปลี่ยนชื่อเป็นค่าจริง:

```bash
sudo kubectl get deployments my-project-api my-project-web -n my-project-prod
sudo kubectl get services my-project-api my-project-web -n my-project-prod
sudo kubectl get secrets,configmaps -n my-project-prod

# ดูเฉพาะชื่อ Secret/ConfigMap ที่ envFrom อ้าง
sudo kubectl get deployment my-project-api -n my-project-prod -o jsonpath='{.spec.template.spec.containers[0].envFrom}'

# แสดงเฉพาะชื่อ key ของ Secret ไม่แสดงค่า
sudo kubectl get secret my-project-api-runtime -n my-project-prod -o go-template='{{range $key, $value := .data}}{{printf "%s\n" $key}}{{end}}'
```

ชื่อ key เช่น `DATABASE_URL`, `DIRECT_DATABASE_URL`, `JWT_SECRET` เป็นตัวอย่าง ให้เทียบกับ source/Prisma schema ของแอปจริง ตัว API สาธิตไม่ได้ใช้ key เหล่านี้ แต่ manifest แสดงวิธีอ้าง runtime Secret ของแอปจริง

ก่อนเปลี่ยน image สคริปต์ API ตรวจว่า Secret ที่ตั้งชื่อไว้มีจริงใน namespace, container อ้าง Secret นั้นผ่าน `envFrom` หรือ `env[].valueFrom.secretKeyRef` และมี key ตาม `REQUIRED_SECRET_KEYS` โดยไม่แสดงค่า Secret การตรวจนี้เกิดหลัง build/push และหลังผู้ใช้งานยืนยัน แต่ก่อน `kubectl set image`; หากไม่ผ่านจะไม่เปลี่ยน image

การตรวจชื่อ key ไม่ยืนยันว่าค่าถูกต้องหรือเชื่อมต่อ DB ได้ และไม่ตรวจทุกการจับคู่ชื่อ env/prefix/override ใน Deployment ต้องเทียบ env mapping ของแอปกับ manifest จริงด้วย

Web ตัวอย่างเป็นหน้า static จึงไม่ต้องใช้ runtime Secret หากเปลี่ยนเป็น Web server ที่ใช้ env ให้คงการอ้าง Secret ของ Deployment ฝั่ง Web ตามแอปจริง ห้ามส่งค่า DB/secret key ไป JavaScript ที่ browser ดาวน์โหลด

ค่า Service `CLUSTER-IP` ที่อ่านได้ ใช้กรอก `CHANGE_ME_API_CLUSTER_IP` และ `CHANGE_ME_WEB_CLUSTER_IP` ไม่ใช่ IP ของ server SSH

## 6. ใช้งานจริงเมื่อระบบบน server มีอยู่แล้ว

1. แก้ค่าด้านบนของสองสคริปต์ให้ตรงกับระบบจริง
2. ตรวจ runtime env และ health endpoint บน server ตามข้อ 5
3. ให้ Git worktree สะอาด และ API อยู่ที่ branch `main` ซึ่ง commit ตรงกับ `origin/main`
4. Login registry แล้วเลือกเรียกสคริปต์ที่ต้องการ release

เครื่อง local ต้องมี Bash, Git, Docker/Buildx, SSH, curl และ awk พร้อมสิทธิ์ push registry เครื่อง server ต้องใช้ sudo kubectl และ curl ได้

ถ้าสร้าง repository ใหม่ ให้ตั้ง `origin` ไปยัง Git repository ของบอสและ push `main` ก่อน API script จะ `git fetch origin` เพื่อเทียบ commit ไม่ได้สร้าง remote ให้

```bash
cd /mnt/d/git/my-project
git status --short
git branch --show-current
git fetch origin
git rev-parse HEAD origin/main

docker login YOUR_REGISTRY
bash ./deploy-api.sh
# หรือ release Web
# bash ./deploy-web.sh
```

แก้ `YOUR_REGISTRY` ก่อนใช้คำสั่ง ตอบ `y`, `Y`, `yes` หรือ `YES` ที่คำถามยืนยันเพื่อเปลี่ยน image กด Enter เพื่อยกเลิก ทั้งสองสคริปต์ build/push ก่อนถาม จึงมี image ใน registry แม้ยกเลิก

API บังคับ `main` และ commit ตรง remote ตามต้นฉบับ Gaia; Web ตรวจ worktree สะอาดและแสดง branch แต่ไม่ได้บังคับ `main` ให้เลือก branch release ให้ถูกก่อนรัน

การ release นี้เปลี่ยน image และคง env ที่ Deployment อ้างไว้เดิม ไม่สร้าง namespace, Secret, ConfigMap, Service หรือ ingress ให้ ไม่รัน Prisma migration และไม่ rollback อัตโนมัติ

## 7. กรณีระบบใหม่ ยังไม่มี Deployment/Service

ใช้ส่วนนี้เฉพาะการติดตั้งครั้งแรก โดยตั้งชื่อจริงแทนค่าตัวอย่างทุกจุด:

1. Build/push image ครั้งแรกจาก source ที่พร้อมใช้งาน แล้วอ่าน digest:

```bash
docker login YOUR_REGISTRY
docker buildx build --platform linux/amd64 -t YOUR_REGISTRY/my-project-api:initial --push ./backend
docker buildx build --platform linux/amd64 -t YOUR_REGISTRY/my-project-web:initial --push ./frontend
docker buildx imagetools inspect YOUR_REGISTRY/my-project-api:initial
docker buildx imagetools inspect YOUR_REGISTRY/my-project-web:initial
```

2. แก้ทุก `CHANGE_ME_*` ใน `server.yaml` ใส่ image แบบ digest ที่อ่านได้จริง
3. ให้ผู้ดูแลเตรียม namespace และ runtime Secret บน server ตามระบบจัดการ credentials ที่ใช้อยู่ ต้องมี Secret ก่อน Pod ใช้งาน และอาจต้องตั้ง imagePullSecret หาก registry ต้องยืนยันตัวตน
4. คัดลอก manifest ที่แก้ครบแล้วไป server และตรวจด้วย `sudo kubectl apply --dry-run=server -f server.yaml` ก่อน เมื่อพร้อมติดตั้งจึงรัน `sudo kubectl apply -f server.yaml` ซึ่งสร้าง/แก้ทรัพยากรจริง
5. รอ Deployment พร้อมทำงาน อ่าน ClusterIP ของ Service มากรอกใน deploy scripts และตั้ง DNS/Ingress/reverse proxy/TLS ให้ public URL และ health ใช้ได้ `server.yaml` ให้เพียง Namespace, Deployment และ Service
6. ตรวจ Pod พร้อมทำงานและ env references แล้ว commit/push ค่าที่แก้ใน deploy scripts ไป `main` ก่อน release ครั้งต่อไปด้วยสองสคริปต์ในข้อ 6

ถ้า namespace/Deployment/Service มีอยู่แล้ว อย่า apply manifest ตัวอย่างทับระบบเดิม ให้ตรวจและใช้ manifest ที่ดูแลอยู่เดิม

## ก่อนรัน ตรวจครบหรือยัง

```bash
# ค้นหาค่าที่ยังไม่ได้แก้ในสองสคริปต์
grep -nE '^[A-Z_]+="[^"]*CHANGE_ME' deploy-api.sh deploy-web.sh

# ตรวจ syntax แบบไม่ deploy
bash -n deploy-api.sh
bash -n deploy-web.sh
```

สคริปต์จะหยุดตั้งแต่ต้นหากค่าตั้งต้นที่จำเป็นยังมี `CHANGE_ME` เมื่อแก้ค่าครบ grep ด้านบนควรไม่มีผลลัพธ์และจะคืน exit code 1 ตามปกติ ไม่ต้องแก้คำว่า `CHANGE_ME` ใน guard ส่วน `server.yaml` ต้องแก้ทุก placeholder เฉพาะเมื่อนำ manifest นั้นไปใช้จริง

ผลตรวจรอบล่าสุดจะบันทึกไว้ท้ายคู่มือนี้ การผ่านในเครื่องหรือการจำลองไม่ยืนยันว่า env และ Kubernetes ของ server จริงพร้อม deploy

## ผลตรวจวันที่ 11 ตุลาคม 2026

| การตรวจ | ผล / ขอบเขต |
|---|---|
| Docker build API และ Web | ผ่านจาก Dockerfile จริง โดยไม่มี `.env` หรือ production env ใน local |
| เปิด containers แล้วตรวจ HTTP | API `/health` และ Web `/` ตอบ HTTP 200; รัน UID 65534 โดยไม่ส่ง DB/secret env |
| deploy scripts แบบจำลอง | 9 tests ผ่าน: placeholders, cancel, approve, Secret หาย/อ้างผิด/key หาย, valueFrom, array ว่าง และ public redirect |
| Bash syntax และ offline suite เดิม | ผ่าน |
| `server.yaml` | YAML อ่านได้ 5 documents; names/selectors/ports/readiness/Secret reference สอดคล้องกัน ยังไม่ได้ validate กับ cluster จริง |
| เอกสารและไฟล์ | ลิงก์และชื่อ `CHANGE_ME_*` ครบ; สคริปต์ Gaia ต้นฉบับไม่ได้แก้ |

สรุปความพร้อม: ไฟล์ตัวอย่าง build/run ในเครื่องได้ และสคริปต์ผ่านการจำลอง ต้องกรอกค่าจริง เตรียม Secret/Deployment/Service/public routing และตรวจ server ก่อน deploy จริง การตรวจนี้ไม่ได้อ่านค่าลับหรือยืนยัน DB connection บน server

หากต้องการรันชุดทดสอบจำลองซ้ำจาก root ของโปรเจกต์ ใช้ Python 3 และ Bash:

```bash
python -B tests/test_deploy.py
```

ชุดทดสอบแทน Git/Docker/SSH/kubectl ด้วยคำสั่งจำลองในโฟลเดอร์ชั่วคราว ไม่ต้องมี local env ไม่ build/push จริง และไม่เชื่อม server หากต้องระบุ Bash เองให้ตั้ง `TEST_BASH` เป็น path ของ Bash ที่ใช้งานได้
