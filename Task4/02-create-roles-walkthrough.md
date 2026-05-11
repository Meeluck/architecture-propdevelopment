# Разбор 02-create-roles.sh

Скрипт создаёт namespace под организационные домены и ClusterRole, которые описывают наборы прав в Kubernetes.

RBAC в Kubernetes состоит из двух частей:

- Role или ClusterRole описывает, что разрешено делать;
- RoleBinding или ClusterRoleBinding описывает, кому это разрешено.

Этот скрипт создаёт только первую часть: роли. Связи пользователей с ролями создаёт `03-bind-users-roles.sh`.

## Шаг 1. Проверка kubectl

Скрипт проверяет:

```bash
command -v kubectl
```

Если `kubectl` не установлен, скрипт завершается.

Ручная проверка:

```bash
kubectl version --client
```

## Шаг 2. Создание namespace

По умолчанию скрипт создаёт namespace:

```text
owner-services
crm
smart-home
data-platform
finance
security
```

В скрипте это задано переменной:

```bash
NAMESPACES="${NAMESPACES:-owner-services crm smart-home data-platform finance security}"
```

Создание идёт через связку:

```bash
kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
```

Смысл команды:

- `kubectl create namespace ... --dry-run=client -o yaml` не создаёт namespace сразу, а генерирует YAML;
- `kubectl apply -f -` применяет этот YAML к кластеру;
- если namespace уже существует, команда не ломается.

Проверить namespace:

```bash
kubectl get namespaces
```

## Шаг 3. Создание ClusterRole `propdev-readonly`

Эта роль даёт только чтение обычных ресурсов:

- `pods`;
- `pods/log`;
- `services`;
- `configmaps`;
- `deployments`;
- `jobs`;
- `ingresses`;
- `networkpolicies`;
- события и другие нечувствительные ресурсы.

Она не даёт доступ к `secrets`.

Ручная проверка после запуска скрипта:

```bash
kubectl describe clusterrole propdev-readonly
```

## Шаг 4. Создание ClusterRole `propdev-namespace-configurator`

Эта роль нужна доменным командам разработки. Она позволяет настраивать прикладные ресурсы внутри конкретного namespace:

- создавать и изменять `deployments`, `statefulsets`, `daemonsets`;
- управлять `services`, `configmaps`, `jobs`, `cronjobs`;
- настраивать `ingresses`, `networkpolicies`, `horizontalpodautoscalers`;
- смотреть логи pod через `pods/log`;
- делать `exec` и `port-forward` для диагностики.

Ограничения роли:

- нет доступа к `secrets`;
- нет прав менять RBAC;
- сама по себе ClusterRole ещё не даёт доступ ко всем namespace. Namespace-ограничение появится через RoleBinding в третьем скрипте.

Проверка:

```bash
kubectl describe clusterrole propdev-namespace-configurator
```

## Шаг 5. Создание ClusterRole `propdev-platform-configurator`

Эта роль для платформенной команды. Она позволяет настраивать инфраструктурные сущности:

- `namespaces`;
- `resourcequotas`;
- `limitranges`;
- `persistentvolumes`;
- `persistentvolumeclaims`;
- `storageclasses`;
- `ingressclasses`;
- `customresourcedefinitions`;
- admission webhook-конфигурации.

Также роль может читать `nodes`, события и RBAC-настройки.

Ограничение: роль не выдаёт доступ к `secrets`.

Проверка:

```bash
kubectl describe clusterrole propdev-platform-configurator
```

## Шаг 6. Создание ClusterRole `propdev-secret-manager`

Это привилегированная роль для команды ИБ. Она позволяет работать с `secrets`:

- `get`;
- `list`;
- `watch`;
- `create`;
- `update`;
- `patch`;
- `delete`.

Дополнительно она может читать `namespaces`, `configmaps` и `serviceaccounts`, чтобы понимать контекст, в котором находятся secrets.

Проверка:

```bash
kubectl describe clusterrole propdev-secret-manager
```

## Что попробовать после скрипта

После второго скрипта роли уже есть, но пользователи ещё не связаны с ролями.

Проверить список ролей:

```bash
kubectl get clusterroles | grep propdev
```

Проверить, что bindings ещё могут отсутствовать:

```bash
kubectl get clusterrolebindings | grep propdev
kubectl get rolebindings -A | grep propdev
```

