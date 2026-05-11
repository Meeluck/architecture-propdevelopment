# Разбор 03-bind-users-roles.sh

Скрипт связывает группы пользователей с ролями. Именно после этого пользователи получают реальные права в Kubernetes.

Важная идея: скрипт не привязывает конкретных пользователей напрямую. Он привязывает группы. Пользователь попадает в группу через поле `O` в клиентском сертификате, который был создан в `01-create-users.sh`.

## Шаг 1. Проверка kubectl

Скрипт проверяет, что доступен `kubectl`:

```bash
command -v kubectl
```

Ручная проверка:

```bash
kubectl version --client
```

## Шаг 2. ClusterRoleBinding для viewer-группы

Скрипт создаёт:

```text
ClusterRoleBinding: propdev-viewers-readonly
Group: propdev-viewers
ClusterRole: propdev-readonly
```

Смысл: все пользователи из группы `propdev-viewers` получают права роли `propdev-readonly`.

Проверить:

```bash
kubectl describe clusterrolebinding propdev-viewers-readonly
```

Ожидаемый результат:

```bash
kubectl auth can-i get pods -A --as=ivan.viewer --as-group=propdev-viewers
kubectl auth can-i get secrets -A --as=ivan.viewer --as-group=propdev-viewers
```

Первый запрос должен вернуть `yes`, второй - `no`.

## Шаг 3. ClusterRoleBinding для platform-группы

Скрипт создаёт две связи для `propdev-platform-admins`:

```text
propdev-platform-admins-configurator -> propdev-platform-configurator
propdev-platform-admins-readonly -> propdev-readonly
```

Смысл:

- первая связь даёт платформенной команде права на настройку инфраструктурных ресурсов;
- вторая связь добавляет обычный read-only доступ, чтобы команда могла смотреть состояние workloads без выдачи доступа к secrets.

Проверить:

```bash
kubectl describe clusterrolebinding propdev-platform-admins-configurator
kubectl describe clusterrolebinding propdev-platform-admins-readonly
```

Пример проверки прав:

```bash
kubectl auth can-i create namespace --as=pavel.platform-admin --as-group=propdev-platform-admins
kubectl auth can-i get secrets -A --as=pavel.platform-admin --as-group=propdev-platform-admins
```

Ожидаемый смысл: namespace создавать можно, secrets читать нельзя.

## Шаг 4. ClusterRoleBinding для security-группы

Скрипт создаёт две связи для `propdev-security-admins`:

```text
propdev-security-admins-secret-manager -> propdev-secret-manager
propdev-security-admins-readonly -> propdev-readonly
```

Смысл:

- `propdev-secret-manager` даёт доступ к secrets;
- `propdev-readonly` даёт возможность смотреть окружение, где эти secrets используются.

Проверить:

```bash
kubectl describe clusterrolebinding propdev-security-admins-secret-manager
kubectl describe clusterrolebinding propdev-security-admins-readonly
```

Пример:

```bash
kubectl auth can-i get secrets -A --as=olga.security-admin --as-group=propdev-security-admins
```

Ожидаемый результат: `yes`.

## Шаг 5. RoleBinding для доменных команд

Для прикладных команд используется `RoleBinding`, а не `ClusterRoleBinding`.

Разница:

- `ClusterRoleBinding` выдаёт роль на уровне всего кластера;
- `RoleBinding` выдаёт роль только внутри одного namespace.

Скрипт вызывает функцию:

```bash
bind_namespace_team "smart-home" "smart-home-team"
```

Она создаёт RoleBinding в namespace `smart-home`:

```bash
kubectl -n smart-home create rolebinding propdev-smart-home-team-namespace-configurator \
  --clusterrole=propdev-namespace-configurator \
  --group=smart-home-team \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Смысл: группа `smart-home-team` получает права роли `propdev-namespace-configurator`, но только внутри namespace `smart-home`.

## Какие namespace и группы связаны

| Namespace | Группа |
| --- | --- |
| `owner-services` | `owner-services-team` |
| `crm` | `crm-team` |
| `smart-home` | `smart-home-team` |
| `data-platform` | `data-platform-team` |
| `finance` | `finance-team` |

Проверить все RoleBinding:

```bash
kubectl get rolebindings -A | grep propdev
```

## Что попробовать после скрипта

Проверка viewer:

```bash
kubectl auth can-i get pods -A --as=ivan.viewer --as-group=propdev-viewers
kubectl auth can-i get secrets -A --as=ivan.viewer --as-group=propdev-viewers
```

Проверка доменной команды:

```bash
kubectl auth can-i create deployment -n smart-home --as=maria.owner-dev --as-group=smart-home-team
kubectl auth can-i create deployment -n finance --as=maria.owner-dev --as-group=smart-home-team
```

Ожидаемый смысл: в `smart-home` можно, в `finance` нельзя.

Проверка security:

```bash
kubectl auth can-i get secrets -A --as=olga.security-admin --as-group=propdev-security-admins
```

Проверка реальными context:

```bash
kubectl --context=ivan.viewer@minikube get pods -A
kubectl --context=ivan.viewer@minikube get secrets -A
kubectl --context=maria.owner-dev@minikube -n smart-home get pods
```

Если имя context отличается, посмотрите точное имя:

```bash
kubectl config get-contexts
```

