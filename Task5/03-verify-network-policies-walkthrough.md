# Разбор 03-verify-network-policies.sh

Скрипт проверяет, что сетевые политики реально разделяют трафик между обычной и административной парами сервисов.

## Как устроена проверка

Скрипт создаёт временные pod на базе Alpine:

```bash
kubectl -n traffic-demo run test-front-end-12345 \
  --rm \
  -i \
  --restart=Never \
  --image=alpine:3.20 \
  --labels="app=traffic-test,role=front-end" \
  --command -- sh -c "wget -qO- -T 2 http://back-end-api-app >/dev/null"
```

Временный pod получает нужную метку `role`, поэтому NetworkPolicy применяет к нему правила как к сервису с этой ролью.

Метка `app=traffic-test` не совпадает с `app=front-end-app`, поэтому сервис `front-end-app` не начнёт случайно направлять трафик на тестовый pod.

## Что означает PASS и FAIL

Для каждого сценария скрипт ожидает один из результатов:

- `allow` - HTTP-запрос должен пройти;
- `deny` - HTTP-запрос должен быть заблокирован политикой и завершиться ошибкой/таймаутом.

Если фактический результат совпал с ожидаемым, выводится `PASS`.

Если не совпал, выводится `FAIL`, а скрипт завершится с ошибкой.

## Какие проверки выполняются

Разрешённый трафик:

| Источник             | Цель                     | Ожидаемо |
| -------------------- | ------------------------ | -------- |
| `front-end`          | `back-end-api-app`       | `allow`  |
| `back-end-api`       | `front-end-app`          | `allow`  |
| `admin-front-end`    | `admin-back-end-api-app` | `allow`  |
| `admin-back-end-api` | `admin-front-end-app`    | `allow`  |

Запрещённый трафик:

| Источник | Цель | Ожидаемо |
| --- | --- | --- |
| `front-end` | `admin-back-end-api-app` | `deny` |
| `admin-front-end` | `back-end-api-app` | `deny` |
| `back-end-api` | `admin-back-end-api-app` | `deny` |
| `unknown-client` | `back-end-api-app` | `deny` |

## Как пройти проверку вручную

Разрешённый сценарий:

```bash
kubectl -n traffic-demo run test-$RANDOM \
  --rm -i \
  --restart=Never \
  --image=alpine:3.20 \
  --labels="app=traffic-test,role=front-end" \
  --command -- sh -c "wget -qO- -T 2 http://back-end-api-app >/dev/null"
```

Ожидаемый результат: команда завершается успешно.

Запрещённый сценарий:

```bash
kubectl -n traffic-demo run test-$RANDOM \
  --rm -i \
  --restart=Never \
  --image=alpine:3.20 \
  --labels="app=traffic-test,role=front-end" \
  --command -- sh -c "wget -qO- -T 2 http://admin-back-end-api-app >/dev/null"
```

Ожидаемый результат: команда завершается ошибкой или таймаутом.

## Если проверки неожиданно проходят там, где должен быть deny

Наиболее вероятная причина - Minikube запущен без CNI, который применяет NetworkPolicy.

Для чистого учебного кластера можно пересоздать Minikube с Calico:

```bash
minikube delete -p minikube
minikube start --driver=docker --cni=calico
```

После этого заново запустите:

```bash
./01-deploy-apps.sh
./02-apply-network-policies.sh
./03-verify-network-policies.sh
```

