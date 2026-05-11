# Разбор 02-apply-network-policies.sh

Скрипт применяет файл `non-admin-api-allow.yaml` с сетевыми политиками.

## Что делает скрипт

Основная команда:

```bash
kubectl apply -f non-admin-api-allow.yaml
```

После применения скрипт показывает список NetworkPolicy:

```bash
kubectl -n traffic-demo get networkpolicies
```

## Какие политики создаются

### `default-deny-all`

Выбирает все pod в namespace `traffic-demo`:

```yaml
podSelector: {}
```

И включает оба направления:

```yaml
policyTypes:
  - Ingress
  - Egress
```

Так как правил `ingress` и `egress` нет, весь входящий и исходящий трафик для pod в namespace запрещён. Это базовая изоляция.

### `allow-dns-egress`

Разрешает всем pod ходить в Kubernetes DNS на порт 53.

Это нужно, чтобы команды вида:

```bash
wget http://back-end-api-app
```

могли сначала превратить имя service в IP-адрес.

### `allow-front-end-traffic`

Выбирает pod с меткой:

```yaml
role: front-end
```

И разрешает:

- входящий TCP/80 только от `role=back-end-api`;
- исходящий TCP/80 только к `role=back-end-api`.

### `allow-back-end-api-traffic`

Выбирает pod с меткой:

```yaml
role: back-end-api
```

И разрешает трафик только с `role=front-end` и к `role=front-end`.

### `allow-admin-front-end-traffic`

Выбирает pod с меткой:

```yaml
role: admin-front-end
```

И разрешает трафик только с `role=admin-back-end-api` и к `role=admin-back-end-api`.

### `allow-admin-back-end-api-traffic`

Выбирает pod с меткой:

```yaml
role: admin-back-end-api
```

И разрешает трафик только с `role=admin-front-end` и к `role=admin-front-end`.

## Итоговая модель доступа

Разрешено:

```text
front-end <-> back-end-api
admin-front-end <-> admin-back-end-api
```

Запрещено:

```text
front-end -> admin-back-end-api
admin-front-end -> back-end-api
back-end-api -> admin-back-end-api
любой pod без разрешённой role -> любой API
```

## Что проверить после скрипта

```bash
kubectl -n traffic-demo get networkpolicies
kubectl -n traffic-demo describe networkpolicy default-deny-all
kubectl -n traffic-demo describe networkpolicy allow-front-end-traffic
kubectl -n traffic-demo describe networkpolicy allow-admin-back-end-api-traffic
```

Если политики создались, но трафик всё равно не фильтруется, проверьте CNI. NetworkPolicy требует сетевой плагин с поддержкой этих политик, например Calico.

