# OpenStack infrastructure for Nextcloud Kubernetes

Stack này cấp hạ tầng ban đầu gồm **3 control-plane VM + 3 worker VM** trên
OpenStack. Số node được điều khiển bằng biến nên có thể tăng worker mà không
nhân bản resource Terraform thủ công.

## Tài nguyên được tạo

- Một network/subnet/router riêng, hoặc dùng network/subnet có sẵn.
- Ba control-plane và ba worker, boot từ Cinder volume theo mặc định.
- Nova server group để phân tán control-plane bằng anti-affinity và worker bằng
  soft anti-affinity.
- Security group chỉ cho phép east-west giữa các node; API `6443` và SSH `22`
  chỉ được mở theo CIDR cấu hình.
- Octavia TCP load balancer cho Kubernetes API `:6443` (có thể tắt nếu cloud
  không cung cấp Octavia).
- Floating IP cho API và cho bootstrap SSH đều tắt mặc định.
- Cloud-init chuẩn bị kernel/sysctl, tắt swap và cài các tiện ích nền. Stack
  **không chạy `kubeadm init` và không lưu join token trong Terraform state**.

Ceph RGW/S3, PostgreSQL và Redis không thuộc stack này. Với mục tiêu Nextcloud
100.000-1.000.000 tài khoản, chúng nên là các cụm stateful độc lập; ba worker ở
đây là node pool khởi đầu để benchmark, không phải capacity đã được cam kết cho
toàn bộ quy mô đó.

## 1. Lấy đúng tên tài nguyên OpenStack

Sau khi nạp RC, dùng các lệnh read-only sau:

```bash
set +x
source ./mars-nguyennd.sh
openstack image list --status active
openstack flavor list
openstack network list --external
openstack keypair list
openstack availability zone list --compute
openstack loadbalancer flavor list
openstack volume type list
```

File RC hiện chứa credential dạng rõ. Hạn chế quyền đọc trước khi sử dụng:

```bash
chmod 600 mars-nguyennd.sh
```

Nên chuyển sang OpenStack application credential và thay credential hiện tại
nếu file từng được commit, gửi qua chat/email, hoặc để ở nơi nhiều người đọc.

## 2. Cấu hình

```bash
cp terraform.tfvars.example terraform.tfvars
```

Sửa tối thiểu năm giá trị `CHANGE_ME`:

- `image_id` (khuyến nghị) hoặc đặt `image_id = null` và dùng `image_name`
- `control_plane_flavor_name`
- `worker_flavor_name`
- `keypair_name`
- `external_network_name`

Khuyến nghị seed ban đầu:

| Nhóm | Số lượng | Điểm bắt đầu |
|---|---:|---|
| Control-plane | 3 | 8 vCPU, 16-32 GiB RAM, root 100 GiB Cinder low-latency |
| Worker | 3 | 32 vCPU, 128 GiB RAM, root 200 GiB; ưu tiên local NVMe cho dữ liệu tạm |

Flavor thực tế phải được chọn theo quota và kết quả load test. Tất cả workload
quan trọng cần còn chạy được khi mất một worker, nên không dùng hết capacity của
ba worker trong trạng thái bình thường.

Pin `image_id` thay vì lấy image theo tên để một image cùng tên mới không làm
thay đổi ngoài ý muốn cả sáu VM. Không đổi image ID đồng loạt trên production;
hãy thêm/rotate từng node sau khi cordon/drain và xác nhận quorum etcd.

Stack hiện dùng volume type mặc định của project cho boot volume. Trước
production, xác nhận loại mặc định là encrypted SSD/low-latency và benchmark
`etcd` fsync; nếu cloud không bảo đảm điều này, cần mở rộng stack để tạo root/data
volume Cinder với `volume_type` cụ thể. Khuyến nghị local NVMe trong bảng không
được stack này tự tạo hoặc mount—nó phải đến từ flavor hoặc một volume riêng.

Nếu chỉ có một AZ tên `nova`, giữ nguyên `availability_zones = ["nova"]`; Nova
server group vẫn cố phân tán VM qua các compute host. Nếu project không có ba
hypervisor khả dụng, đổi control-plane sang `soft-anti-affinity` mới có thể tạo
đủ VM, nhưng khi đó không còn bảo đảm phân tán vật lý.

Chọn `node_subnet_cidr` trước lần apply đầu tiên và kiểm tra không trùng Pod CIDR,
Service CIDR, VPN/on-prem hay mạng Ceph. Neutron subnet không thể mở rộng tùy ý
sau khi cluster đã chạy. Khi `create_network = false`, Terraform tự lấy CIDR từ
subnet hiện có; subnet đó phải có router/egress và đường floating-IP phù hợp.

## 3. Khởi tạo và kiểm tra plan

```bash
set +x
source ./mars-nguyennd.sh
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=nextcloud-k8s.tfplan
```

Kiểm tra plan phải đúng các số lượng chính:

- 3 `openstack_compute_instance_v2.control_plane`
- 3 `openstack_compute_instance_v2.worker`
- 6 Neutron port
- 1 API load balancer, 1 listener, 1 pool, 3 member nếu Octavia được bật
- Không có floating IP nếu chưa chủ động bật

Sau khi xác nhận quota và plan:

```bash
terraform apply nextcloud-k8s.tfplan
terraform output kubernetes_api_endpoint
terraform output -raw ansible_inventory > inventory.ini
```

`kubernetes_api_endpoint` trả về đúng định dạng `VIP-or-DNS:6443` để đưa vào
`controlPlaneEndpoint` của Kubeadm/Kubespray/RKE2; output này không có tiền tố
`https://`. `kubernetes_api_url` là URL dành cho API client. Cloud-init chỉ
chuẩn bị OS; bước tiếp theo dùng một công cụ bootstrap Kubernetes để cài
container runtime, kubelet/control-plane và CNI.

Inventory dùng private IP. Máy chạy Ansible/Kubespray phải có route qua
VPN/private network; nếu chạy từ Internet, cấu hình `ProxyJump` qua floating IP
bootstrap hoặc bastion riêng. Không để floating IP bootstrap tồn tại lâu dài.

Trước khi bootstrap, đợi cloud-init hoàn tất trên từng VM:

```bash
sudo cloud-init status --wait
sudo tail -n 100 /var/log/cloud-init-output.log
```

## 4. Scale worker

Sửa trong `terraform.tfvars`:

```hcl
worker_count = 6
```

Sau đó chạy lại `terraform plan` và `terraform apply`. Các key `worker-01` đến
`worker-03` không đổi, Terraform chỉ thêm `worker-04` đến `worker-06`. Terraform
chỉ tạo VM; sau apply phải chạy playbook scale của Kubespray/Ansible/RKE2 để cài
và join các node mới. Stack này không tự cài Kubernetes Cluster Autoscaler.

Không giảm `worker_count` trước khi đã cordon, drain và remove đúng node khỏi
Kubernetes bằng công cụ bootstrap. Nếu giảm biến trước, Terraform sẽ xóa VM
trực tiếp và có thể làm gián đoạn workload hoặc mất dữ liệu local/ephemeral.

## Lưu ý vận hành

- `anti-affinity` cần đủ compute host và quota; nếu không, Nova sẽ từ chối lịch
  VM thay vì đặt hai control-plane lên cùng host.
- Worker được chia server group theo `worker_server_group_size` để tránh quota
  member khi scale. Không thay đổi kích thước shard tùy tiện sau apply vì có thể
  làm node chuyển server group và bị thay thế.
- Xác minh Octavia flavor/provider thực sự cung cấp topology HA
  (ACTIVE_STANDBY/OVN HA). Một VIP không mặc nhiên có nghĩa load balancer HA.
- Listener API dùng idle timeout một giờ để không cắt sớm các kết nối Kubernetes
  watch/log/exec dài. Xác nhận giới hạn Octavia của cloud trước khi thay đổi
  `api_listener_idle_timeout_ms`.
- `allowed_cidrs` trên Octavia có phụ thuộc phiên bản Octavia của cloud. Nếu API
  public được bật, không dùng `0.0.0.0/0`; chỉ cho phép IP quản trị/VPN.
- Boot volume đặt `delete_on_termination = true`; `terraform destroy` sẽ xóa VM
  và root volume. Không lưu dữ liệu ứng dụng trên root volume.
- Lưu Terraform state trong backend mã hóa, có versioning và khóa state trước
  khi nhiều người cùng vận hành. Không commit `terraform.tfvars`, state, plan hay
  OpenStack RC; `.gitignore` đã chặn các file này.
- Khi tắt `create_api_load_balancer`, output API trỏ vào control-plane đầu tiên
  và chưa phải endpoint HA. Phải triển khai một VIP/HAProxy/keepalived tương
  đương trước khi bootstrap production. Keepalived/floating VIP trực tiếp trên
  port VM cần Neutron port riêng hoặc `allowed_address_pairs`; nếu thiếu, port
  security sẽ chặn traffic của VIP.
- Security group hiện cho phép east-west giữa các node để không khóa nhầm CNI.
  Sau khi chốt Calico/Cilium và chế độ overlay, nên thu hẹp về đúng port của
  kube-apiserver, etcd, kubelet và CNI; routed/BGP CNI còn cần thiết kế Neutron
  allowed-address-pairs/trunk và anti-spoofing riêng.
- API load balancer trong stack chỉ phục vụ kube-apiserver. Nextcloud ingress
  cần một load balancer/Ingress Controller riêng ở bước cài Kubernetes.
