# Dependency Graph Audit — copilot-cli

## Scope & approach

Audit này tập trung vào **dependency thể hiện trong source repo** (không bao gồm binary nội bộ của `copilot` do repo này không chứa mã nguồn implementation chính):

- File manifest/dependency trong repo
- Lockfile hiện có
- Mức độ pin version
- Mức độ reproducible build

## 1) Danh sách dependency hiện tại

### 1.1 Runtime / install channel dependencies

| Khu vực | Dependency | Vị trí | Kiểu pin |
|---|---|---|---|
| Cài đặt npm | `@github/copilot` | `README.md` | Không pin (latest hoặc tag prerelease) |
| Cài đặt Homebrew | `copilot-cli`, `copilot-cli@prerelease` | `README.md` | Theo formula/cask của brew, không pin theo commit trong repo này |
| Cài đặt WinGet | `GitHub.Copilot`, `GitHub.Copilot.Prerelease` | `README.md`, `install.sh` | Không pin phiên bản cụ thể mặc định |
| Cài đặt script trực tiếp | GitHub Release artifact `copilot-{platform}-{arch}.tar.gz` | `install.sh` | Mặc định lấy `releases/latest`; có hỗ trợ pin bằng `VERSION` |

### 1.2 CI / automation dependencies

| Khu vực | Dependency | Vị trí | Kiểu pin |
|---|---|---|---|
| GitHub Actions | `actions/github-script@v7` | `.github/workflows/close-single-word-issues.yml` | Pin theo major tag (movable) |
| GitHub Actions | `actions/stale@v9` | `.github/workflows/no-response.yml`, `.github/workflows/stale-issues.yml` | Pin theo major tag (movable) |
| GitHub Actions | `actions/create-github-app-token@v2` | `.github/workflows/winget.yml` | Pin theo major tag (movable) |
| CircleCI executor image | `cimg/base:current` | `.circleci/config.yml` | Floating tag |
| Dev container image | `mcr.microsoft.com/devcontainers/universal:2` | `.devcontainer/devcontainer.json` | Pin theo major tag (movable) |
| CLI tool trong workflow | `gh` CLI trên runner image | Nhiều workflow dùng `gh ...` | Phụ thuộc tool preinstalled của `ubuntu-latest` (floating) |
| CLI tool tải runtime | `wingetcreate` từ `https://aka.ms/wingetcreate/latest` | `.github/workflows/winget.yml` | Floating `latest` |

## 2) Kiểm tra lockfile

### Kết quả

Không phát hiện lockfile cho các ecosystem phổ biến (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `go.sum`, `Cargo.lock`, v.v.).

### Nhận định

- Với trạng thái repo hiện tại (chủ yếu docs + script + workflow), việc không có lockfile cho app code là dễ hiểu.
- Tuy nhiên, phần automation vẫn phụ thuộc nhiều thành phần **floating** nên tính tái lập vẫn thấp dù không có package manager manifest truyền thống.

## 3) Đánh giá pin version

### 3.1 Điểm tốt

- `install.sh` cho phép pin release qua biến `VERSION`.

### 3.2 Rủi ro chính

- Mặc định `install.sh` dùng `releases/latest` → khó tái lập giữa các lần cài.
- GitHub Actions pin theo `@v*` thay vì commit SHA → có rủi ro supply-chain nếu tag dịch chuyển hoặc action bị compromise.
- CircleCI `cimg/base:current` và GitHub runner `ubuntu-latest` là floating base environment.
- `wingetcreate/latest` được tải trực tiếp, chưa checksum/khóa phiên bản.

## 4) Phân loại risk

| Risk | Mức độ | Vì sao |
|---|---|---|
| Third-party action không pin SHA | High | Chuỗi CI có thể thay đổi mà không đổi code repo |
| Download artifact từ `latest` không verify checksum | High | Rủi ro integrity và khó rollback chính xác |
| Base image / runner floating (`current`, `*-latest`) | Medium | Build/test behavior có thể drift theo thời gian |
| Không có SBOM/dependency inventory tự động | Medium | Khó theo dõi thay đổi dependency và lỗ hổng |
| Không có lockfile ứng dụng | Low (hiện tại) | Repo không chứa app source/package manifest rõ ràng |

## 5) Reproducible build assessment

**Kết luận:** mức reproducibility hiện tại là **thấp đến trung bình** (đặc biệt ở pipeline automation), do phụ thuộc vào nhiều nguồn “latest/current/movable tags”.

## 6) Đề xuất cải thiện (ưu tiên)

### Ưu tiên 1 — Giảm rủi ro supply chain

1. Pin toàn bộ `uses:` trong workflow sang **full commit SHA**.
2. Với `wingetcreate`, pin bản phát hành cụ thể thay vì `latest` + verify checksum/signature.
3. Trong `install.sh`, thêm khuyến nghị rõ ràng: production nên set `VERSION` cố định và (nếu có thể) verify checksum release asset.

### Ưu tiên 2 — Tăng reproducibility môi trường CI

1. Tránh `cimg/base:current`, pin image digest/tag cố định.
2. Đánh giá thay `ubuntu-latest` bằng version cụ thể ở workflow cần tính ổn định cao.

### Ưu tiên 3 — Quản trị dependency liên tục

1. Bật Dependabot cho GitHub Actions updates.
2. Tạo định kỳ báo cáo dependency/SBOM cho automation assets.
3. Thêm checklist “dependency pinning” vào PR template hoặc repo policy.

## 7) Mapping theo acceptance criteria

- [x] Có danh sách dependency
- [x] Có phân loại risk
- [x] Có đề xuất cải thiện

## Reference note

Tham chiếu best practice từ GitHub Docs: pin action theo full-length commit SHA để giảm rủi ro mutable tags.
