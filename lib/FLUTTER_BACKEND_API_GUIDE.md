# Flutter Backend API Guide

Dokumen ini ditujukan untuk tim Flutter agar paham endpoint backend yang tersedia, pola request/response, dan fitur FE apa saja yang perlu disiapkan.

## 1. Base URL

- Base API: `http://<host-backend>/api`
- Contoh lokal Laragon: `http://localhost/vcs_be/public/api`
- Semua request Flutter sebaiknya pakai `application/json`

Header standar:

```http
Accept: application/json
Content-Type: application/json
Authorization: Bearer <jwt_token>
```

Catatan:

- Endpoint `wb/*` pada dasarnya disiapkan untuk integrasi WB.NET, bukan flow utama Flutter operator.
- Endpoint tanpa middleware JWT tetap boleh diakses tanpa token, tetapi untuk aplikasi mobile tetap lebih aman jika semua flow operator diawali login.

## 2. Pola Response Backend

Mayoritas response backend konsisten seperti ini:

```json
{
  "success": true,
  "message": "Deskripsi hasil",
  "data": {}
}
```

Response error umum:

```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "field_name": ["Pesan error"]
  }
}
```

Status code yang perlu ditangani di Flutter:

- `200`: sukses
- `201`: sukses create
- `401`: token invalid, token expired, atau belum login
- `403`: ditolak oleh flow bisnis atau approval manager
- `404`: data tidak ditemukan
- `422`: validasi gagal atau urutan proses belum terpenuhi
- `423`: tiket sedang menunggu approval manager
- `500` atau `503`: gangguan server

## 3. Auth dan Session

### Login

- `POST /api/login`

Body:

```json
{
  "username": "operator1",
  "password": "secret"
}
```

Response penting:

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "token": "jwt-token",
    "token_type": "bearer",
    "expires_at": "2026-05-17T10:00:00.000000Z",
    "user": {
      "user_id": "...",
      "username": "operator1",
      "roles": ["admin"]
    }
  }
}
```

### Refresh token

- `POST /api/refresh`
- Header wajib: `Authorization: Bearer <old_token>`

### Ambil user login

- `GET /api/user`

### Logout

- `POST /api/logout`

### Yang perlu dibuat di Flutter

- `AuthService`
- `AuthRepository`
- penyimpanan token lokal, misalnya secure storage
- interceptor untuk inject bearer token
- handler auto refresh saat `401`
- menu/fitur berbasis `roles`

## 4. Alur Bisnis yang Harus Dipahami FE

Flow utama backend:

1. Registrasi kendaraan dibuat
2. WB IN selesai
3. QC Sampling
4. QC Lab
5. Unloading
6. WB OUT
7. Completed

Status yang sering muncul di FE:

- `wb_in`
- `qc_sampling`
- `qc_lab`
- `qc_lab_hold`
- `qc_lab_rejected`
- `start_unloading`
- `start_unloading_hold`
- `wb_out`
- `completed`
- `random_check`
- `cancel`

Catatan implementasi FE:

- Jangan hanya mengandalkan status lokal di Flutter. Selalu refresh data dari backend sebelum membuka form aksi.
- Untuk halaman kerja operator, endpoint `vehicles` adalah sumber daftar tiket yang paling aman karena backend sudah memfilter tiket yang valid untuk tahap tersebut.

## 5. Endpoint yang Relevan untuk Flutter

## 5.1 Dashboard dan Lookup Registrasi

### List registrasi dashboard

- `GET /api/registrations?limit=100`

Return utama:

- `registration_id`
- `card_no`
- `wb_ticket_no`
- `plate_number`
- `driver_name`
- `commodity_type`
- `transaction_code`
- `regist_status`
- `created_at`

### Lookup detail registrasi

- `GET /api/wb/registration?identifier=<registration_id|wb_ticket_no|card_no>`

Dipakai saat FE butuh detail tiket berdasarkan scan kartu, nomor tiket, atau registration id.

Field penting di response detail:

- identitas kendaraan dan driver
- `commodity_type`
- `regist_status`
- data berat `bruto_weight`, `tara_weight`
- timestamp tap in/out
- flag CCTV dan auto action jika ada

## 5.2 Tap In dan Tap Out

Tap adalah bagian penting dari flow operator. Jangan submit sampling, lab, atau unloading sebelum syarat tap terpenuhi.

### Tap in

- `POST /api/tap/in`

Body minimum:

```json
{
  "card_no": "RFID001",
  "process_type": "sampling"
}
```

Nilai `process_type` yang diterima:

- `auto`
- `wb`
- `wb_out`
- `sampling`
- `lab`
- `loading`
- `start_loading`
- `unloading`
- `start_unloading`
- `resampling-1`
- `resampling-2`
- `relab-1`
- `relab-2`
- `reunloading-1`
- `reunloading-2`

Catatan:

- `loading`, `start_loading`, dan `start_unloading` akan diperlakukan sebagai `unloading` di backend.
- Untuk flow normal Flutter operator, yang paling sering dipakai adalah `sampling`, `lab`, `unloading`, `wb`, dan `wb_out`.

### Tap out

- `POST /api/tap/out`

Body minimum:

```json
{
  "card_no": "RFID001",
  "process_type": "sampling"
}
```

### Cek histori tap

- `GET /api/tap/{registration_id}`

### Cek sequence tap

- `GET /api/tap/sequence/{registration_id}`

Yang perlu dibuat di Flutter:

- komponen scan/input `card_no`
- state untuk status proses aktif
- tombol `Tap In` dan `Tap Out`
- guard UI agar submit form hanya aktif jika sequence backend sudah valid

## 5.3 QC Sampling

Tersedia untuk 3 komoditas:

- `/api/qc/sampling/cpo/*`
- `/api/qc/sampling/pome/*`
- `/api/qc/sampling/pk/*`

### Ambil kendaraan siap sampling

- `GET /api/qc/sampling/cpo/vehicles`
- `GET /api/qc/sampling/pome/vehicles`
- `GET /api/qc/sampling/pk/vehicles`

Response berisi daftar tiket yang sudah lolos syarat backend, misalnya CCTV valid, WB IN selesai, dan sampling tap in sudah ada.

### Submit sampling

- `POST /api/qc/sampling/cpo/create`
- `POST /api/qc/sampling/pome/create`
- `POST /api/qc/sampling/pk/create`

Contoh body CPO:

```json
{
  "registration_id": "REG-001",
  "oil_temp": 45.5,
  "visual_color": "normal",
  "photos": [
    "data:image/jpeg;base64,/9j/4AAQSk..."
  ]
}
```

Catatan implementasi:

- `photos` adalah array base64 image string
- maksimal 4 foto
- base64 harus diawali `data:image/...`
- backend akan simpan ke folder publik dan membuat record foto

Tambahan FE yang perlu ada:

- daftar kendaraan siap sampling
- form input sampling
- picker kamera atau gallery lalu konversi ke base64
- preview foto sebelum submit
- detail sampling per tiket `GET /api/qc/sampling/{commodity}/{identifier}`
- statistik bila dibutuhkan `GET /api/qc/sampling/{commodity}/statistics`

## 5.4 QC Lab

Tersedia untuk 3 komoditas:

- `/api/qc/lab/cpo/*`
- `/api/qc/lab/pome/*`
- `/api/qc/lab/pk/*`

### Ambil kendaraan siap lab

- `GET /api/qc/lab/cpo/vehicles`
- `GET /api/qc/lab/pome/vehicles`
- `GET /api/qc/lab/pk/vehicles`

Query opsional:

- `include_rejected=true`
- `include_cancel=true`

### Submit hasil lab

- `POST /api/qc/lab/cpo/submit`
- `POST /api/qc/lab/pome/submit`
- `POST /api/qc/lab/pk/submit`

Contoh body umum:

```json
{
  "registration_id": "REG-001",
  "ffa": 3.1,
  "moisture": 0.25,
  "dobi": 2.8,
  "iv": 55.2,
  "remarks": "hasil normal",
  "remarks_hold": null,
  "status": "approved",
  "photos": [
    "data:image/jpeg;base64,/9j/4AAQSk..."
  ]
}
```

Field penting:

- `status`: `approved`, `hold`, `rejected`
- `remarks_hold` dipakai saat tiket di-hold
- foto maksimal 4

Yang perlu diperhatikan FE:

- tiket lab hanya boleh muncul jika sampling sudah selesai
- backend menolak jika `tap in` lab belum ada
- pada kondisi `random_check`, submit bisa diblok backend sampai ada approval manager

## 5.5 Unloading

### CPO

- `GET /api/unloading/cpo/vehicles`
- `POST /api/unloading/cpo/create`
- `GET /api/unloading/cpo/statistics`
- `GET /api/unloading/cpo/{identifier}`

Contoh body create CPO:

```json
{
  "registration_id": "REG-001",
  "tank_id": 1,
  "hole_id": 2,
  "status": "approved",
  "remarks": "ok",
  "photos": [
    "data:image/jpeg;base64,/9j/4AAQSk..."
  ]
}
```

### POME

- `GET /api/unloading/pome/vehicles`
- `POST /api/unloading/pome/create`
- `GET /api/unloading/pome/statistics`
- `GET /api/unloading/pome/{identifier}`

### PK

PK punya flow tambahan untuk resampling dan reunloading.

Endpoint utama PK:

- `GET /api/unloading/pk/vehicles`
- `POST /api/unloading/pk/start`
- `POST /api/unloading/pk/finish`
- `POST /api/unloading/pk/start-reunloading-1`
- `POST /api/unloading/pk/finish-reunloading-1`
- `POST /api/unloading/pk/start-reunloading-2`
- `POST /api/unloading/pk/finish-reunloading-2`
- `POST /api/unloading/pk/create`
- `GET /api/unloading/pk/statistics`
- `GET /api/unloading/pk/{identifier}`

Saran untuk FE:

- pisahkan UI PK dari CPO dan POME karena flow-nya tidak identik
- tampilkan indikator cycle resampling bila status tiket PK berubah setelah hold

## 5.6 Manager Check

Jika Flutter juga dipakai manager, endpoint ini perlu dibuat service tersendiri:

- `GET /api/manager/check/tickets`
- `GET /api/manager/check/tickets/{registrationId}/{stage}`
- `POST /api/manager/check/sampling`
- `POST /api/manager/check/lab`
- `POST /api/manager/check/unloading`
- `GET /api/manager/check/statistics`
- `GET /api/manager/check/{checkId}`

Gunanya:

- approval random check
- approval hasil sampling, lab, atau unloading
- melihat histori pemeriksaan manager

## 5.7 Master Data

Dipakai terutama untuk form unloading.

### Tanks

- `GET /api/master/tanks`
- `GET /api/master/tanks/{id}`

Filter opsional:

- `GET /api/master/tanks?is_active=1`

### Holes

- `GET /api/master/holes`
- `GET /api/master/holes/{id}`

Filter opsional:

- `GET /api/master/holes?is_active=1`

Yang perlu dibuat di Flutter:

- cache master data tank dan hole
- dropdown selector saat create unloading

## 6. Endpoint yang Tidak Perlu Jadi Prioritas Flutter

Endpoint berikut lebih cocok untuk integrasi sistem lain atau operasional web internal:

- `POST /api/wb/registration`
- `PUT /api/wb/registration/status`
- `PUT /api/wb/registration`
- `DELETE /api/wb/registration`
- `POST /api/wb/in`
- `POST /api/wb/out`
- semua endpoint socket dan CCTV session

Endpoint itu tetap boleh didokumentasikan di Postman, tapi tidak perlu dijadikan modul utama Flutter kecuali memang ada use case khusus dari tim operasional.

## 7. Kontrak Data yang Perlu Disiapkan di Flutter

Minimal model yang perlu ada:

- `AuthUser`
- `LoginResponse`
- `RegistrationSummary`
- `RegistrationDetail`
- `TapRecord`
- `VehicleQueueItem`
- `SamplingPayload`
- `LabPayload`
- `UnloadingPayload`
- `Tank`
- `Hole`
- `ManagerCheckTicket`

Minimal layer service yang perlu ada:

- `AuthApiService`
- `RegistrationApiService`
- `TapApiService`
- `SamplingApiService`
- `LabApiService`
- `UnloadingApiService`
- `MasterDataApiService`
- `ManagerCheckApiService`

## 8. Checklist Fitur FE Flutter

Checklist minimum:

- login dan logout
- simpan bearer token
- dashboard list registrasi
- search tiket by `registration_id`, `wb_ticket_no`, atau `card_no`
- halaman tap in dan tap out
- halaman queue sampling per komoditas
- halaman submit sampling dengan upload foto base64
- halaman queue lab per komoditas
- halaman submit lab dengan status `approved`, `hold`, `rejected`
- halaman queue unloading per komoditas
- dropdown tank dan hole
- halaman detail tiket
- penanganan error `401`, `422`, `423`, dan `500`

Checklist tambahan jika role manager ada di Flutter:

- inbox manager check
- detail approval per stage
- approve, hold, reject dari mobile

## 9. Catatan Teknis Penting untuk Flutter

- Semua upload gambar saat ini berbasis base64, bukan multipart file.
- Banyak endpoint memvalidasi urutan proses. Jadi FE harus menampilkan pesan backend apa adanya jika gagal `422`.
- Jangan hardcode tiket tampil berdasarkan status saja. Pakai endpoint `vehicles` per tahap.
- Untuk PK, flow berbeda dan perlu UI khusus.
- Roles dari response login harus dipakai untuk menentukan menu mana yang tampil.

## 10. Referensi Tambahan

- Postman collection: `postman/VCS_API.postman_collection.json`
- Flow bisnis dan ERD umum: `DOCS.md`
