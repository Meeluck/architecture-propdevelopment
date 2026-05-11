# Задание 4  Защита доступа к кластеру Kubernetes

В этом задании вы поработаете над решением технической задачи. Вам необходимо организовать ролевой доступ к Kubernetes для пользователей кластера.

Вот контекст и факты о ролевой модели:

- Большинство бизнес-сервисов разворачивается в среде Kubernetes. Необходимо ограничить доступ к управлению кластером для различных групп пользователей.
- Необходимо защитить кластер с помощью предоставления привилегированных действий (например, просмотра секретов) для определённых групп пользователей.
- Кроме привилегированных групп пользователей, необходимо выделить ещё минимум две группы пользователей. У первой группы есть право только на просмотр ресурсов кластера. Вторая другая группа пользователей может настраивать кластер.
- Необходимо разграничить доступ к ресурсам кластера, исходя из организационной структуры компании.

## Что нужно сделать

1. Поднимите пустой Minikube. В этот раз вы будете работать без тестового приложения. Изучать код не нужно, поэтому сфокусируйтесь на подготовке скриптов. Они должны будут отражать решения, которые получились у вас по итогу работы над первыми тремя заданиями. Для этого вам понадобится пустой Minikube.
2. Определите все роли и их полномочия при работе с Kubernetes. Мы подготовили шаблон таблицы. Заполните её: укажите там роли, их полномочия и группы пользователей, которые им соответствуют.
3. Подготовьте скрипты для создания пользователей. Рекомендуем создать не менее двух пользователей.
4. Подготовьте скрипты, чтобы создать роли. Они должны соответствовать ролям из вашей таблицы.
5. Подготовьте скрипты, чтобы связать пользователей с ролями.

Когда вы выполните задание, у вас должно получиться три файла: по одному скрипту на третий, четвёртый и пятый пункты задания. Когда будете сдавать работу, загрузите заполненную таблицу и скрипты в директорию Task4 в рамках пул-реквеста.

---

## Решение

| Роль                             | Права роли                                                                                                                                                                                                                                                                                                                                                                                                                                       | Группы пользователей                                                                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `propdev-readonly`               | Просмотр нечувствительных ресурсов кластера: `namespaces`, `nodes` в режиме чтения, `pods`, `pods/log`, `services`, `endpoints`, `configmaps`, `persistentvolumeclaims`, события, workloads из `apps`, `jobs/cronjobs`, `ingresses`, `networkpolicies`, `horizontalpodautoscalers`, `poddisruptionbudgets`. Роль не даёт доступ к `secrets` и не позволяет изменять ресурсы.                                                                     | `propdev-viewers`: аудиторы, аналитики, QA, техническая поддержка, продуктовые менеджеры.                                                         |
| `propdev-namespace-configurator` | Настройка прикладных ресурсов только в namespace, с которым связана команда: создание, изменение и удаление `pods`, `deployments`, `statefulsets`, `daemonsets`, `replicasets`, `services`, `configmaps`, `jobs`, `cronjobs`, `ingresses`, `networkpolicies`, `horizontalpodautoscalers`, `poddisruptionbudgets`, `persistentvolumeclaims`; просмотр `pods/log` и `serviceaccounts`. Роль не даёт доступ к `secrets` и не позволяет менять RBAC. | Доменные команды: `owner-services-team`, `crm-team`, `smart-home-team`, `data-platform-team`, `finance-team`.                                     |
| `propdev-platform-configurator`  | Настройка инфраструктуры кластера без доступа к секретам: `namespaces`, `resourcequotas`, `limitranges`, `persistentvolumes`, `persistentvolumeclaims`, `storageclasses`, `ingressclasses`, `networkpolicies`, `customresourcedefinitions`, admission webhook-конфигурации; просмотр `nodes`, событий и RBAC-настроек.                                                                                                                           | `propdev-platform-admins`: DevOps/SRE/platform-инженеры.                                                                                          |
| `propdev-secret-manager`         | Привилегированный доступ к секретам: просмотр, создание, изменение и удаление `secrets` во всех namespace; просмотр `namespaces`, `configmaps` и `serviceaccounts` для контекста.                                                                                                                                                                                                                                                                | `propdev-security-admins`: команда информационной безопасности и доверенные администраторы, отвечающие за секреты, ключи и интеграционные токены. |

## Как проверить корректность выполнения

### 1. Проверить, что Minikube запущен

```bash
minikube status
kubectl get nodes
```

Ожидаемый результат:

- `minikube status` показывает запущенные `host`, `kubelet` и `apiserver`;
- `kubectl get nodes` показывает один node Minikube со статусом `Ready`.

### 2. Запустить скрипты в правильном порядке

```bash
cd /Users/alexandermilakov/Study/YA_Software_Architecture/SP_5/architecture-propdevelopment/Task4

./01-create-users.sh
./02-create-roles.sh
./03-bind-users-roles.sh
```

Скрипты идемпотентны: их можно запускать повторно, если нужно перепроверить результат.

После `01-create-users.sh` появится директория `generated-users/` с приватными ключами и сертификатами учебных пользователей. Это локальные артефакты проверки, их не нужно добавлять в pull request.

### 3. Проверить созданные namespace

```bash
kubectl get namespaces owner-services crm smart-home data-platform finance security
```

Ожидаемый результат: все шесть namespace существуют.

### 4. Проверить созданные роли

```bash
kubectl get clusterrole propdev-readonly
kubectl get clusterrole propdev-namespace-configurator
kubectl get clusterrole propdev-platform-configurator
kubectl get clusterrole propdev-secret-manager
```

Для детальной проверки правил можно выполнить:

```bash
kubectl describe clusterrole propdev-readonly
kubectl describe clusterrole propdev-namespace-configurator
kubectl describe clusterrole propdev-platform-configurator
kubectl describe clusterrole propdev-secret-manager
```

### 5. Проверить связи групп с ролями

```bash
kubectl get clusterrolebindings | grep propdev
kubectl get rolebindings -A | grep propdev
```

Ожидаемый результат:

- есть `ClusterRoleBinding` для групп `propdev-viewers`, `propdev-platform-admins`, `propdev-security-admins`;
- есть `RoleBinding` для доменных команд в namespace `owner-services`, `crm`, `smart-home`, `data-platform`, `finance`.

### 6. Проверить права через kubectl auth can-i

Пользователь только для просмотра может читать обычные ресурсы:

```bash
kubectl auth can-i get pods -A --as=ivan.viewer --as-group=propdev-viewers
```

Ожидаемый ответ:

```text
yes
```

Этот же пользователь не должен читать секреты:

```bash
kubectl auth can-i get secrets -A --as=ivan.viewer --as-group=propdev-viewers
```

Ожидаемый ответ:

```text
no
```

Доменная команда может настраивать ресурсы в своём namespace:

```bash
kubectl auth can-i create deployment -n smart-home --as=maria.owner-dev --as-group=smart-home-team
```

Ожидаемый ответ:

```text
yes
```

Та же команда не должна настраивать чужой namespace:

```bash
kubectl auth can-i create deployment -n finance --as=maria.owner-dev --as-group=smart-home-team
```

Ожидаемый ответ:

```text
no
```

Платформенная команда может управлять инфраструктурными ресурсами:

```bash
kubectl auth can-i create namespace --as=pavel.platform-admin --as-group=propdev-platform-admins
```

Ожидаемый ответ:

```text
yes
```

Но платформенная команда не должна читать секреты:

```bash
kubectl auth can-i get secrets -A --as=pavel.platform-admin --as-group=propdev-platform-admins
```

Ожидаемый ответ:

```text
no
```

Команда ИБ должна иметь доступ к секретам:

```bash
kubectl auth can-i get secrets -A --as=olga.security-admin --as-group=propdev-security-admins
```

Ожидаемый ответ:

```text
yes
```

### 7. Проверить реальные kube-context пользователей

После `01-create-users.sh` в kubeconfig должны появиться context для пользователей:

```bash
kubectl config get-contexts | grep minikube
```

Можно проверить доступ через context пользователя:

```bash
kubectl --context=ivan.viewer@minikube get pods -A
kubectl --context=ivan.viewer@minikube get secrets -A
kubectl --context=maria.owner-dev@minikube -n smart-home get pods
```

Ожидаемый смысл результата:

- `ivan.viewer` может смотреть pods;
- `ivan.viewer` получает запрет при попытке посмотреть secrets;
- `maria.owner-dev` может работать в namespace `smart-home`.

Если context называется иначе, точное имя можно посмотреть командой:

```bash
kubectl config get-contexts
```
