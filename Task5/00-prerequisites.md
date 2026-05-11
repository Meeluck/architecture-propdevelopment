# Что нужно подготовить для Task5

Для задания нужны:

| Инструмент                                    | Зачем нужен                                                                |
| --------------------------------------------- | -------------------------------------------------------------------------- |
| Docker Desktop или другой driver для Minikube | Запуск локального Kubernetes-кластера.                                     |
| `minikube`                                    | Управление локальным кластером.                                            |
| `kubectl`                                     | Создание pod, service и NetworkPolicy.                                     |
| CNI с поддержкой NetworkPolicy                | Без него политики будут созданы, но трафик не будет реально фильтроваться. |

## Важный нюанс про NetworkPolicy

Kubernetes API умеет хранить объекты `NetworkPolicy`, но применять их должен сетевой плагин кластера. Если кластер запущен на CNI без поддержки NetworkPolicy, команды `kubectl apply -f non-admin-api-allow.yaml` пройдут успешно, но проверки трафика покажут, что запретов нет.

Для Minikube удобно стартовать кластер с Calico:

```bash
minikube start --driver=docker --cni=calico
```

Если Minikube уже был создан без Calico, проще удалить учебный кластер и создать заново:

```bash
minikube delete -p minikube
minikube start --driver=docker --cni=calico
```

Это удалит локальный учебный кластер Minikube. Для задания это нормально, если в нём нет нужных данных.

## Проверка перед запуском скриптов

```bash
minikube status
kubectl get nodes
kubectl get pods -n kube-system
```

Ожидаемый смысл:

- Minikube запущен;
- node находится в статусе `Ready`;
- в `kube-system` есть системные pod, включая DNS и CNI-компоненты.

Отдельно проверьте, что виден сетевой плагин с поддержкой NetworkPolicy:

```bash
kubectl -n kube-system get pods | grep -E 'calico|cilium'
```

Если команда ничего не выводит, пересоздайте учебный Minikube с `--cni=calico`.
