# Разбор 01-create-users.sh

Скрипт создаёт учебных пользователей Kubernetes через клиентские сертификаты Minikube и добавляет для них отдельные kube-context в локальный kubeconfig.

Важно: в Kubernetes нет обычного объекта `User`, который можно создать командой `kubectl create user`. Kubernetes получает имя пользователя и группы из механизма аутентификации. В этом задании имя пользователя берётся из поля `CN` сертификата, а группы - из полей `O`.

## Что создаёт скрипт

| Пользователь           | Группы                                   |
| ---------------------- | ---------------------------------------- |
| `ivan.viewer`          | `propdev-viewers`                        |
| `maria.owner-dev`      | `owner-services-team`, `smart-home-team` |
| `dmitry.crm-dev`       | `crm-team`                               |
| `pavel.platform-admin` | `propdev-platform-admins`                |
| `olga.security-admin`  | `propdev-security-admins`                |

## Шаг 1. Проверка инструментов

Скрипт проверяет, что доступны команды:

```bash
kubectl
minikube
openssl
```

Самостоятельно можно проверить так:

```bash
command -v kubectl
command -v minikube
command -v openssl
```

Если команда ничего не выводит, инструмент не установлен или не попал в `PATH`.

## Шаг 2. Проверка, что Minikube запущен

В скрипте это делает команда:

```bash
minikube -p "$PROFILE" status
```

Ручная проверка:

```bash
minikube status
```

Если кластер не запущен:

```bash
minikube start --driver=docker
```

## Шаг 3. Обновление текущего kube-context

Скрипт выполняет:

```bash
minikube -p "$PROFILE" update-context
```

Это нужно, чтобы `kubectl` смотрел именно в Minikube, а не в какой-то другой кластер из вашего kubeconfig.

Проверить текущий контекст:

```bash
kubectl config current-context
```

## Шаг 4. Проверка CA Minikube

Скрипт ищет:

```bash
~/.minikube/ca.crt
~/.minikube/ca.key
```

`ca.crt` - публичный сертификат центра сертификации Minikube.

`ca.key` - приватный ключ CA. Через него скрипт подписывает клиентские сертификаты учебных пользователей.

Проверить наличие файлов:

```bash
ls -la ~/.minikube/ca.crt ~/.minikube/ca.key
```

## Шаг 5. Создание директории для сертификатов

Скрипт создаёт директорию:

```bash
Task4/generated-users
```

В ней будут лежать ключи, CSR и сертификаты пользователей. Это учебные секретные материалы, их не нужно добавлять в git.

## Шаг 6. Создание ключа пользователя

Для каждого пользователя скрипт делает RSA key:

```bash
openssl genrsa -out generated-users/ivan.viewer/ivan.viewer.key 2048
```

Ключ - это приватный файл пользователя. Kubernetes будет доверять запросам, подписанным этим ключом, если сертификат подписан CA Minikube.

## Шаг 7. Создание CSR

CSR - certificate signing request. В нём задаётся имя пользователя и группы:

```bash
openssl req \
  -new \
  -key generated-users/ivan.viewer/ivan.viewer.key \
  -out generated-users/ivan.viewer/ivan.viewer.csr \
  -subj "/CN=ivan.viewer/O=propdev-viewers"
```

Соответствие Kubernetes:

- `CN=ivan.viewer` станет username;
- `O=propdev-viewers` станет group.

Если у пользователя несколько групп, в subject будет несколько `O`, например:

```bash
/CN=maria.owner-dev/O=owner-services-team/O=smart-home-team
```

## Шаг 8. Подписание сертификата CA Minikube

Скрипт подписывает CSR:

```bash
openssl x509 \
  -req \
  -in generated-users/ivan.viewer/ivan.viewer.csr \
  -CA ~/.minikube/ca.crt \
  -CAkey ~/.minikube/ca.key \
  -CAserial generated-users/ca.srl \
  -out generated-users/ivan.viewer/ivan.viewer.crt \
  -days 365 \
  -sha256
```

После этого появляется клиентский сертификат `.crt`, который Kubernetes сможет принять.

## Шаг 9. Добавление пользователя в kubeconfig

Скрипт добавляет credentials:

```bash
kubectl config set-credentials ivan.viewer \
  --client-certificate=generated-users/ivan.viewer/ivan.viewer.crt \
  --client-key=generated-users/ivan.viewer/ivan.viewer.key \
  --embed-certs=true
```

Это сохраняет сертификат и ключ в локальный kubeconfig.

## Шаг 10. Создание context

Скрипт создаёт context вида:

```bash
ivan.viewer@minikube
```

Команда в скрипте:

```bash
kubectl config set-context ivan.viewer@minikube \
  --cluster=minikube \
  --user=ivan.viewer
```

Проверить contexts:

```bash
kubectl config get-contexts
```

## Что попробовать после скрипта

Сразу после создания пользователей права ещё не выданы. Поэтому запрос от имени пользователя может получить `Forbidden`:

```bash
kubectl --context=ivan.viewer@minikube get pods -A
```

Это нормально. Права появятся после `02-create-roles.sh` и `03-bind-users-roles.sh`.

