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



## Требования

- Yandex Cloud аккаунт
- Terraform >= 1.0
- Ansible >= 2.10
- SSH-доступ к ВМ

---

## Безопасность

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
## Ограничения

Проект запускался из WSL Windows, речь идёт о специфических ограничениях при использовании become_user: postgres в Ansible внутри WSL, особенно когда выполняется удалённый shell через ansible-playbook с become_user на postgres.
________________________________________

Проблема	Причина	Обход / Решение
❌ Failed to set permissions on temporary files... A+user:postgres:rx:allow	В WSL нет полноценной поддержки ACL (access control lists), которые Ansible использует при become_user	Вместо become_user: postgres используем shell: sudo -u postgres ...
❌ pg_ctlcluster ... promote завершается с ошибкой server is not in standby mode	Повторный запуск playbook без предварительной проверки статуса сервера	Добавлена проверка через pg_is_in_recovery() перед promote
❌ Невозможно использовать become_user: postgres в некоторых модулях Ansible	Ansible пытается использовать chmod с расширенными правами, несовместимыми с WSL или удалённой машиной без setfacl	Решение — явно вызывать sudo -u postgres внутри shell
________________________________________

Что было сделано:

Вместо привычного:
```
- name: Insert test student
  become_user: postgres
  shell: |
    psql -d sysadmin_db -c ...
```
Было написано:
```
- name: Insert test student
  shell: |
    sudo -u postgres psql -d sysadmin_db -c ...
Также на pg-standby в задаче промоутирования добавили условие, чтобы не пытаться продвигать кластер, если он уже в active-режиме:
shell: |
  if sudo -u postgres psql -d sysadmin_db -tAc "SELECT pg_is_in_recovery()" | grep -q t; then
    echo "Promoting..."
    pg_ctlcluster 14 main promote
  else
    echo "Already promoted"
  fi
  ```
________________________________________

WSL как управляющий узел (где запускается Ansible) работает хорошо, но с ограничениями по ACL, become_user и root-правами. Поэтому:
•	Используем sudo -u postgres напрямую
•	Избегаем become_user в WSL при работе с удалёнными пользователями вроде postgres
•	Добавляем логические проверки (pg_is_in_recovery()), чтобы избежать ошибок при повторных запусках


## 🧑‍💻 Авторы

**Алексей Потанин**   [avpotanin@gmail.com](mailto:avpotanin@gmail.com)
GitHub: [https://github.com/potashka](https://github.com/potashka)
