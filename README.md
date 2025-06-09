# PostgreSQL HA Cluster Setup & Check via Ansible

## Описание проекта

Этот проект предназначен для **развёртывания и проверки PostgreSQL-кластера** с репликацией в режиме `master → standby`, а также проверки доступности данных с клиента.

Кластер разворачивается на **трёх удалённых машинах**:

- `pg-master` — главный сервер PostgreSQL
- `pg-standby` — реплика (standby)
- `pg-client` — клиент, подключающийся к `pg-master`

---

## Технологии и средства

- **Ansible** — автоматизация установки и конфигурации
- **PostgreSQL 14** — основная СУБД
- **pg_basebackup** — создание standby-реплики
- **systemd** — управление сервисами PostgreSQL
- **SSH** — доступ к удалённым машинам
- **Unix-пользователь `postgres`** — используется для администрирования СУБД

---

## Структура проекта

```
postgres_cluster/
├── terraform/           # Terraform-манифесты для создания ВМ
├── ansible/             # Ansible для настройки кластеров
│   ├── inventory/       # inventory.ini с IP-адресами ВМ
│   ├── group_vars/      # Общие переменные
│   ├── roles/           # Роли: master, standby, client
│   └── site.yml         # Основной плейбук
|   |__ check.yml        # Плэйбук для проверки

```

---

## Запуск

### 1. Клонируйте репозиторий и создайте структуру



### 2. Перейдите в каталог terraform и настройте переменные

```bash
cd postgres_cluster/terraform
cp terraform.tfvars.example terraform.tfvars
# Заполните значения (cloud_id, folder_id, путь до JSON-ключа и SSH ключа)
```
Пример trea
### 3. Разверните инфраструктуру

```bash
terraform init
terrafom plan
terraform apply
```

### 4. Перейдите в Ansible и настройте кластер

```bash
cd ../ansible
ansible-playbook -i inventory/inventory.ini site.yml
```

---

## Проверка

Выполните:

```bash
cd ansible
ansible-playbook -i inventory.ini check.yml
ansible-playbook -i inventory.ini promote_standby.yml
```

### ansible-playbook -i inventory.ini check.yml
Этот плейбук проверяет корректность настройки кластера PostgreSQL, включая репликацию и доступность данных.

Что именно он проверяет:

#### На основном сервере (pg-master):

наличие записи о пользователе repuser в pg_hba.conf (разрешение репликации);

значение wal_level в postgresql.conf (должно быть replica);

доступ пользователя sysadmin в pg_hba.conf;

значение параметра listen_addresses (для подключения извне);

доступность таблицы студенты в базе sysadmin_db (SELECT * FROM студенты LIMIT 5).

#### На резервном сервере (pg-standby):

включён ли параметр hot_standby в postgresql.conf;

доступ пользователя sysadmin в pg_hba.conf;

чтение таблицы студенты (SELECT * FROM студенты LIMIT 5);

количество строк в таблице (SELECT COUNT(*));

наличие конкретной строки с id=3 (SELECT * FROM студенты WHERE id=3);

статус сервера (находится ли в режиме реплики) — pg_is_in_recovery().

Результаты всех проверок сохраняются в лог-файлы на каждом сервере:

- /home/ubuntu/check_postgres_pg-master.log
- /home/ubuntu/check_postgres_pg-standby.log

### ansible-playbook -i inventory.ini promote_standby.yml

Этот плейбук переводит резервный сервер в режим основного (promote), и затем добавляет / обновляет запись в таблице студенты.

Что именно он делает:

Проверяет, находится ли pg-standby в режиме реплики.

Если да — выполняет pg_ctlcluster 14 main promote.

Ждёт, пока кластер выйдет из режима реплики (pg_is_in_recovery() = false).

Добавляет тестовую запись в таблицу студенты с ID 3 (если её ещё нет).

Обновляет ФИО студента с id = 3 на проверочное:

Потанин Алексей Владиславович

Выводит результат запроса SELECT * FROM студенты WHERE id = 3;



## 📎 Требования

- Yandex Cloud аккаунт
- Terraform >= 1.0
- Ansible >= 2.10
- SSH-доступ к ВМ

---

## 🛡️ Безопасность

- Используется один SSH-ключ для всех машин
- Все пароли и логины можно переопределить через `group_vars/all.yml`

Пример all.yml:
```
postgres_version: 14
pg_data_dir: /var/lib/postgresql/14/main
replication_user: repuser
replication_password: ""
sysadmin_user: sysadmin
sysadmin_password: ""
sysadmin_db: sysadmin_db
your_name: 'Потанин Алексей Владиславович'
student_id: 3
```
---

## 🧑‍💻 Авторы

Автор: `s14861078`
Проект подготовлен в рамках практикума по запуску PostgreSQL-кластера.
