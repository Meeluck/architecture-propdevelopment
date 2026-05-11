# Разбор 01-deploy-apps.sh

Скрипт создаёт один namespace и разворачивает в нём четыре nginx pod вместе с Kubernetes Service.

## Что создаётся

Namespace:

```text
traffic-demo
```

Pod и Service:

| Pod/Service | Метки |
| --- | --- |
| `front-end-app` | `app=front-end-app`, `role=front-end` |
| `back-end-api-app` | `app=back-end-api-app`, `role=back-end-api` |
| `admin-front-end-app` | `app=admin-front-end-app`, `role=admin-front-end` |
| `admin-back-end-api-app` | `app=admin-back-end-api-app`, `role=admin-back-end-api` |

Метка `role` используется сетевыми политиками как роль сервиса. Метка `app` добавлена, чтобы Service выбирал только свой pod и не цеплял временные тестовые pod с такой же `role`.

## Шаг 1. Проверка kubectl

Скрипт проверяет, что доступна команда:

```bash
kubectl
```

Ручная проверка:

```bash
kubectl version --client
```

## Шаг 2. Создание namespace

В скрипте:

```bash
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
```

Смысл:

- `--dry-run=client -o yaml` генерирует YAML без немедленного создания;
- `kubectl apply -f -` применяет YAML;
- повторный запуск не ломается, если namespace уже существует.

Ручная проверка:

```bash
kubectl get namespace traffic-demo
```

## Шаг 3. Создание pod и service

Скрипт использует `kubectl run` с `--expose`:

```bash
kubectl -n traffic-demo run front-end-app \
  --image=nginx \
  --labels="app=front-end-app,role=front-end" \
  --expose \
  --port=80 \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Эта команда создаёт два объекта:

- `Pod` с nginx;
- `Service` типа `ClusterIP`, который направляет трафик на этот pod.

Аналогично создаются ещё три сервиса.

## Шаг 4. Ожидание готовности pod

Скрипт ждёт, пока каждый pod станет `Ready`:

```bash
kubectl -n traffic-demo wait --for=condition=Ready pod -l role=front-end --timeout=120s
```

Если образ nginx ещё не загружен, Kubernetes сначала скачает его, поэтому первый запуск может занять время.

## Что проверить после скрипта

```bash
kubectl -n traffic-demo get pods --show-labels
kubectl -n traffic-demo get services --show-labels
```

Ожидаемый результат:

- четыре pod в статусе `Running`;
- четыре service с именами `front-end-app`, `back-end-api-app`, `admin-front-end-app`, `admin-back-end-api-app`;
- у каждого pod и service есть корректная метка `role`.

