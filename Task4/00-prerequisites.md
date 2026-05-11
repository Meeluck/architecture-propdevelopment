# Что нужно установить и подготовить

Этот набор скриптов рассчитан на учебный локальный кластер Minikube. В промышленном Kubernetes пользователей обычно подключают через корпоративный IdP/OIDC, а не через ручную выдачу клиентских сертификатов. Для задания с Minikube такой подход удобен: можно увидеть, как Kubernetes связывает пользователя, группу и RBAC-права.

## 1. Необходимые инструменты

Должны быть установлены:

| Инструмент | Зачем нужен |
| --- | --- |
| Docker Desktop или другой Minikube driver | Minikube запускает локальный Kubernetes внутри Docker/VM. На macOS проще всего использовать Docker Desktop. |
| `minikube` | Создаёт и управляет локальным Kubernetes-кластером. |
| `kubectl` | CLI для работы с Kubernetes API: создание namespace, ролей, bindings, проверка прав. |
| `openssl` | Создаёт ключи, CSR и клиентские сертификаты пользователей. |
| `bash` | Запускает подготовленные `.sh`-скрипты. |
| `git` | Нужен для сдачи результата в pull request. |

Для macOS через Homebrew:

```bash
brew install minikube kubectl openssl
```

Docker Desktop ставится отдельно. После установки его нужно запустить и дождаться статуса, что Docker engine работает.

## 2. Как подготовить пустой Minikube

Перейдите в директорию задания:

```bash
cd /Users/alexandermilakov/Study/YA_Software_Architecture/SP_5/architecture-propdevelopment/Task4
```

Запустите Minikube:

```bash
minikube start --driver=docker
```

Проверьте состояние:

```bash
minikube status
kubectl get nodes
```

Ожидаемый смысл результата:

- `minikube status` показывает, что host, kubelet и apiserver запущены;
- `kubectl get nodes` показывает один node со статусом `Ready`.

Если Docker Desktop не запущен, `minikube status` или `minikube start` будут падать с ошибкой подключения к Docker socket.

## 3. Порядок запуска скриптов

Скрипты нужно запускать в таком порядке:

```bash
./01-create-users.sh
./02-create-roles.sh
./03-bind-users-roles.sh
```

Почему порядок именно такой:

1. Сначала создаются пользователи и их группы через клиентские сертификаты.
2. Потом создаются namespace и роли Kubernetes.
3. В конце группы пользователей связываются с ролями.

## 4. Как проверять результат

После выполнения всех скриптов можно проверять права через `kubectl auth can-i`:

```bash
kubectl auth can-i get pods -A --as=ivan.viewer --as-group=propdev-viewers
kubectl auth can-i get secrets -A --as=ivan.viewer --as-group=propdev-viewers
kubectl auth can-i create deployment -n smart-home --as=maria.owner-dev --as-group=smart-home-team
kubectl auth can-i get secrets -A --as=olga.security-admin --as-group=propdev-security-admins
```

Ожидаемый смысл:

- viewer может смотреть обычные ресурсы;
- viewer не может смотреть secrets;
- доменная команда может настраивать ресурсы в своём namespace;
- security-admin может работать с secrets.
