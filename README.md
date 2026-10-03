<div align="center">

<img src="icon.jpg" width="128" alt="ProksiFi Logo" style="border-radius: 24px;" />

# ProksiFi (antigravity-Proksi_Patch)

**Легковесный клиент маршрутизации и шлюз для Google Antigravity, YouTube и Telegram на Windows.**

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://github.com/ProksiPatch/antigravity-Proksi_Patch)
[![Version](https://img.shields.io/badge/Release-v1.1.6%20(October%202026)-success)](https://github.com/ProksiPatch/antigravity-Proksi_Patch/releases/latest)
[![Telegram Channel](https://img.shields.io/badge/Telegram-@antigravity__proxy-2CA5E0?logo=telegram&logoColor=white)](https://t.me/antigravity_proxy)
[![Size](https://img.shields.io/badge/Size-25.2%20MB-blue)](https://github.com/ProksiPatch/antigravity-Proksi_Patch/releases/latest)
[![Core](https://img.shields.io/badge/Engine-Mihomo%20Core-00C7B7)](https://github.com/MetaCubeX/mihomo)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

[**⚡ Скачать ProksiFi_Setup_v1.1.6.exe (25 МБ)**](https://github.com/ProksiPatch/antigravity-Proksi_Patch/releases/download/v1.1.6/ProksiFi_Setup_v1.1.6.exe) • [**Proksi_Patch_Setup.exe**](https://github.com/ProksiPatch/antigravity-Proksi_Patch/releases/download/v1.1.6/Proksi_Patch_Setup.exe) • [**Telegram-канал**](https://t.me/antigravity_proxy)

</div>

---

### Основные возможности

* **Google Antigravity & AI Models (Gemini, Claude Sonnet 4.6, Claude 3.7):** прямое подключение к европейскому шлюзу (Франкфурт 🇩🇪), стабильная работа без региональных блокировок и ошибок генерации.
* **YouTube 4K без буферизации:** автоматическая фильтрация QUIC (UDP 443) с мгновенным переключением на TCP TLS 1.3 в туннеле.
* **Telegram:** надежная маршрутизация медиа-серверов и чатов в обход локальных сетевых ограничений.
* **Fail-Safe защита сети при перезагрузке:** интеллектуальный агент трея ожидает инициализацию сетевых интерфейсов до 15 секунд. Если ядро не запущено — системный прокси автоматически деактивируется, гарантируя, что интернет на ПК никогда не пропадёт.
* **Аппаратная привязка без дублирования ключей:** стабильная идентификация устройства (Hardware UUID) сохраняет ваш профиль при любых переустановках и обновлениях.
* **Zero Anti-Cheat Conflicts:** не используются драйверы уровня ядра (`wintun.sys` / `WinDivert.sys`). Античиты игр (BattlEye, EasyAntiCheat, Vanguard, VAC) работают в штатном режиме без перехвата пакетов.
* **Split Tunneling:** локальный трафик (банки, Госуслуги, VK, Яндекс, маркетплейсы и онлайн-игры) идёт напрямую через вашего провайдера на максимальной скорости.
* **Тихие OTA-обновления:** маршруты и списки блокировок синхронизируются в фоне с сервером без необходимости переустанавливать приложение.

---

### Схема маршрутизации

```mermaid
graph LR
    User[Клиент Windows] -->|Antigravity / Google AI / YouTube / Telegram| Gateway[Шлюз Франкфурт 🇩🇪]
    Gateway --> Internet[Целевые сервисы]
    
    User -->|Steam / Игры / Банки / Сайты РФ| Direct[Прямой домашний канал]
```

---

### Системные требования

* **ОС:** Windows 10 / Windows 11 (x64)
* **Права:** Права администратора **не требуются** (программа работает в пространстве пользователя)
* **Сеть:** Доступ к портам 443 и 7979

---

### Установка

1. Скачайте официальный инсталлятор [**`ProksiFi_Setup_v1.1.6.exe`**](https://github.com/ProksiPatch/antigravity-Proksi_Patch/releases/download/v1.1.6/ProksiFi_Setup_v1.1.6.exe) (или совместимый [`Proksi_Patch_Setup.exe`](https://github.com/ProksiPatch/antigravity-Proksi_Patch/releases/download/v1.1.6/Proksi_Patch_Setup.exe)).
2. Запустите установщик (права администратора не требуются, установка идёт в пользовательский профиль `%APPDATA%\ProksiFi`).
3. По завершении установки программа автоматически активирует маршрутизацию и разместит статусную иконку в системном трее Windows.

---

### Управление через трей

После установки в панели задач появляется иконка статуса:
* **Зелёный индикатор:** прокси-клиент активен, порт готов к передаче пакетов.
* **Серый индикатор:** системный прокси отключен, весь трафик идёт напрямую через провайдера.
* Меню по правому клику позволяет временно отключить туннелирование, выполнить проверку OTA-обновлений или полностью закрыть приложение.

---

### Решение частых ошибок (Troubleshooting)

#### 1. «There was an unexpected issue setting up your account»
* **Причина:** Требуется подтверждение совершеннолетия учетной записи Google.
* **Решение:** Пройдите официальную проверку возраста по ссылке: [Google Age Verification](https://myaccount.google.com/age-verification).

#### 2. «User location is not supported (400)»
* **Причина:** Утечка DNS или некорректная глобальная маршрутизация доменов API.
* **Решение:**
  * **Не устанавливайте** кастомные зарубежные DNS на весь сетевой адаптер Windows (иначе перестанут работать российские сайты, банки и Госуслуги).
    ```text
    daily-cloudcode-pa.googleapis.com
    generativelanguage.googleapis.com
    ```

#### 3. «Agent execution terminated due to error» (после обновления)
* **Причина:** Зависли фоновые процессы либо возник конфликт сторонних патчей / анлокеров.
* **Решение:**
  1. Завершите все зависшие процессы через Диспетчер задач: `antigravity.exe`, `language_server.exe`, `agy.exe`.
  2. Не накатывайте несколько разных анлокеров поверх друг друга во избежание повреждения файлов.
  3. Если файлы среды повреждены — выполните чистую переустановку, предварительно удалив папки:
     ```cmd
     %LocalAppData%\Programs\Antigravity
     %AppData%\Antigravity
     %UserProfile%\.antigravity-ide
     ```

---

### Удаление

Для удаления приложения достаточно:
1. Выбрать **«Выход»** в контекстном меню трея (сетевой стек Windows автоматически сбросится в исходное состояние).
2. Удалить рабочую директорию: `%APPDATA%\ProksiFi`.

---

<div align="center">
  <sub>Лицензия MIT. Разработано для сообщества.</sub>
</div>
