# Задание 5 Управление трафиком внутри кластера Kubertnetes

В этом задании вам нужно разграничить трафик между сервисами, которые развёрнуты в кластере Kubernetes:

- Вам необходимо добавить новый сервис. В терминах Kubernetes это под (pod). При этом нужно запретить другим подам с ним взаимодействовать.
- Необходимо изолировать трафик к новому сервису от других подов.

## Что нужно сделать

1. В кластере, внутри одного namespace, вам необходимо развернуть четыре сервиса. В качестве самого сервиса используйте образ Nginx (вам не нужно создавать логику приложения в этом заданий).
Назначьте метки для сервисов.

2. Метки выполняют функцию ролей для сервиса:

   1. `front-end`
   2. `back-end-api`
   3. `admin-front-end`
   4. `admin-back-end-api`

    Для назначения меток используйте команду:

    `kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80`

    > 💡 Сервис можно назвать, добавив суффикс -app к имени сервиса. Так будет проще различать имя сервиса и его метку.

3. Создайте сетевые политики.

    Настройте сетевые политики так, чтобы разделить трафик между сервисами API (admin-back-end-api, back-end-api) и сервисами, которые используют их UI (front-end, admin-front-end).

    Таким образом, сетевые политики должны разрешить сетевой трафик в обе стороны между парой сервисов front-end и back-end-api, а также admin-front-end и admin-back-end-api.

    Сохраните сетевую политику в файл. Можете назвать его non-admin-api-allow.yaml. Затем примените сетевую политику, используя команду:

    ```bash
        kubectl apply -f non-admin-api-allow.yaml
    ```

    Когда настроите и примените сетевые политики, проверьте, что трафик есть между сервисами, для которых он разрешён, но его нет между сервисами, для которых он запрещён. Для этого используйте команду:

    ```bash
        kubectl run test-$RANDOM --rm -i -t --image=alpine -- sh
    / # wget -qO- --timeout=2 http://apiserver
    ```

Когда всё будет готово, загрузите файл с сетевыми политиками в директорию Task5.

---

## Решение

Для задания используется namespace `traffic-demo`. В нём разворачиваются четыре nginx pod и четыре Kubernetes Service:

| Service/Pod | Метки | Назначение |
| --- | --- | --- |
| `front-end-app` | `app=front-end-app`, `role=front-end` | UI обычной пользовательской части. |
| `back-end-api-app` | `app=back-end-api-app`, `role=back-end-api` | API обычной пользовательской части. |
| `admin-front-end-app` | `app=admin-front-end-app`, `role=admin-front-end` | UI административной части. |
| `admin-back-end-api-app` | `app=admin-back-end-api-app`, `role=admin-back-end-api` | API административной части. |

Сетевые политики описаны в файле `non-admin-api-allow.yaml`.

Модель доступа:

| Направление | Результат |
| --- | --- |
| `front-end` <-> `back-end-api` | Разрешено. |
| `admin-front-end` <-> `admin-back-end-api` | Разрешено. |
| `front-end` -> `admin-back-end-api` | Запрещено. |
| `admin-front-end` -> `back-end-api` | Запрещено. |
| Pod без разрешённой `role` -> API-сервисы | Запрещено. |

Изоляция сделана через `default-deny-all`: сначала весь входящий и исходящий трафик в namespace запрещается, затем отдельными правилами разрешаются только две нужные пары сервисов. Дополнительно разрешён egress к Kubernetes DNS, чтобы pod могли обращаться к service по имени.

## Файлы решения

| Файл | Назначение |
| --- | --- |
| `01-deploy-apps.sh` | Создаёт namespace `traffic-demo`, четыре pod nginx и четыре service. |
| `02-apply-network-policies.sh` | Применяет `non-admin-api-allow.yaml`. |
| `03-verify-network-policies.sh` | Проверяет разрешённые и запрещённые направления трафика. |
| `non-admin-api-allow.yaml` | NetworkPolicy-манифесты. |
| `00-prerequisites.md` | Что нужно подготовить перед запуском. |
| `01-deploy-apps-walkthrough.md` | Пошаговый разбор первого скрипта. |
| `02-apply-network-policies-walkthrough.md` | Пошаговый разбор сетевых политик. |
| `03-verify-network-policies-walkthrough.md` | Пошаговый разбор проверок. |

## Важное условие для проверки

NetworkPolicy работает только если CNI-плагин кластера умеет применять сетевые политики. Для Minikube удобно использовать Calico:

```bash
minikube start --driver=docker --cni=calico
```

Проверить, что в кластере есть CNI-компоненты, можно так:

```bash
kubectl -n kube-system get pods | grep -E 'calico|cilium'
```

Если команда ничего не выводит, текущий Minikube, скорее всего, не будет реально блокировать трафик по NetworkPolicy.

Если Minikube уже был создан без CNI с поддержкой NetworkPolicy, политики могут создаваться, но трафик не будет блокироваться. Для чистого учебного кластера можно пересоздать Minikube:

```bash
minikube delete -p minikube
minikube start --driver=docker --cni=calico
```

## Как запустить решение

Перейдите в директорию задания:

```bash
cd /Users/alexandermilakov/Study/YA_Software_Architecture/SP_5/architecture-propdevelopment/Task5
```

Запустите скрипты по порядку:

```bash
./01-deploy-apps.sh
./02-apply-network-policies.sh
./03-verify-network-policies.sh
```

## Как проверить вручную

Проверить namespace, pod и service:

```bash
kubectl get namespace traffic-demo
kubectl -n traffic-demo get pods --show-labels
kubectl -n traffic-demo get services --show-labels
```

Ожидаемый результат:

- есть namespace `traffic-demo`;
- четыре pod находятся в статусе `Running`;
- четыре service существуют и имеют корректные label `role`.

Проверить NetworkPolicy:

```bash
kubectl -n traffic-demo get networkpolicies
```

Ожидаемый список:

```text
default-deny-all
allow-dns-egress
allow-front-end-traffic
allow-back-end-api-traffic
allow-admin-front-end-traffic
allow-admin-back-end-api-traffic
```

Проверить разрешённый трафик:

```bash
kubectl -n traffic-demo run test-$RANDOM \
  --rm -i \
  --restart=Never \
  --image=alpine:3.20 \
  --labels="app=traffic-test,role=front-end" \
  --command -- sh -c "wget -qO- -T 2 http://back-end-api-app >/dev/null"
```

Ожидаемый результат: команда завершается успешно.

Проверить запрещённый трафик:

```bash
kubectl -n traffic-demo run test-$RANDOM \
  --rm -i \
  --restart=Never \
  --image=alpine:3.20 \
  --labels="app=traffic-test,role=front-end" \
  --command -- sh -c "wget -qO- -T 2 http://admin-back-end-api-app >/dev/null"
```

Ожидаемый результат: команда завершается ошибкой или таймаутом.

Полная автоматическая проверка:

```bash
./03-verify-network-policies.sh
```

Если в запрещённых сценариях получаете успешные HTTP-ответы, значит политики не применяются сетевым плагином. Проверьте, что Minikube запущен с `--cni=calico`.
