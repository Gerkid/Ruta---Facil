<div align="center">

# 🚚 Ruta Fácil — Delivery Route Optimizer

### *Optimizador Logístico de Última Milla & Ruteo Inteligente para Repartidores*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-15%20%28One%20UI%207%29-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)
[![Google Maps](https://img.shields.io/badge/Google%20Maps-API%20HD-4285F4?style=for-the-badge&logo=google-maps&logoColor=white)](https://cloud.google.com/maps-platform)
[![SQLite](https://img.shields.io/badge/SQLite-Master%20v6-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](#)

<p align="center">
  <b>Ruta Fácil</b> es una solución móvil de alto rendimiento desarrollada en Flutter, diseñada para repartidores y conductores de paquetería de última milla (Temu, Courier local y Logística comercial). Resuelve el problema del viajero (TSP) mediante algoritmos de desenredo geométrico 2-Opt, trazado vial calle por calle y control interactivo en segundo plano.
</p>

---

</div>

## 🌟 Características Principales

<table>
  <tr>
    <td width="50%">
      <h3>🧠 1. Optimización TSP con Zonificación</h3>
      <ul>
        <li><b>Algoritmo 2-Opt Determinístico:</b> Elimina el 100% de cruces en 8 y retrocesos innecesarios.</li>
        <li><b>Zonificación por Cuadrantes:</b> Limpia las entregas manzana por manzana en sectores contiguos.</li>
        <li><b>Punto Final Fijo (Tu Casa / Almacén):</b> La última parada se programa automáticamente cerca de tu destino para no retornar vacío.</li>
      </ul>
    </td>
    <td width="50%">
      <h3>🛣️ 2. Trazado Vial Real (Curvas de Calles)</h3>
      <ul>
        <li><b>Geometría HD de Pistas:</b> Dibuja las curvas reales, sentidos de calles, óvalos y puentes en lugar de líneas rectas.</li>
        <li><b>Motor Híbrido:</b> Integración con Google Directions API y OSRM en micro-lotes paralelos de alto rendimiento (&lt; 400 ms).</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td width="50%">
      <h3>📸 3. Ingesta Masiva & OCR Offline</h3>
      <ul>
        <li><b>Cámara OCR (Google ML Kit):</b> Escaneo y extracción automática de direcciones, teléfonos y códigos de tracking en etiquetas físicas.</li>
        <li><b>Google Takeout CSV/JSON:</b> Importación instantánea de listas guardadas con notas de paquetes integradas.</li>
        <li><b>Recepción WhatsApp:</b> Captura de chinchetas compartidas mediante deep linking.</li>
      </ul>
    </td>
    <td width="50%">
      <h3>🔔 4. Despacho & Samsung Now Bar</h3>
      <ul>
        <li><b>Notificación Interactiva (One UI 7):</b> Controles rápidos en pantalla de bloqueo, AOD y barra de estado.</li>
        <li><b>Flujo Continuo en Google Maps:</b> Al presionar <code>[ ✅ Entregado ]</code>, marca la entrega en SQLite y navega a la siguiente parada sin salir de Google Maps.</li>
      </ul>
    </td>
  </tr>
</table>

---

## 📱 Interfaz & Experiencia de Usuario (UI/UX)

* **Panel Deslizable Inferior (*Draggable Sheet*):** Vista panorámica del mapa plateado con buscador flotante y hoja expandible con lista de paradas.
* **Caja de Notas Interactiva:** Edición de notas de paquete (ej. `493`, `704`, `883`) y teléfonos con un solo toque.
* **Métricas en Vivo:** Indicador en tiempo real de kilometraje total, duración estimada y hora calculada de llegada (ETA) por parada.
* **Pestañas Sincronizadas:** Gestión segmentada entre `Pendientes` y `Hecho` con botón de deshacer inmediato.

---

## 🛠️ Stack Tecnológico

| Componente | Tecnología | Propósito |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.x / Dart | Núcleo multiplataforma de alto rendimiento |
| **Motor de Mapas** | Google Maps Flutter SDK | Renderizado de mapa plateado y pines numerados |
| **Base de Datos** | SQLite (Sqflite) | Persistencia local y auto-migración de versiones |
| **Visión Artificial** | Google ML Kit Text Recognition | Reconocimiento óptico de caracteres offline |
| **Ruteo & Geometría** | Google Directions API / OSRM | Matriz de tiempos y trazado vial calle por calle |
| **Notificaciones** | Flutter Local Notifications | Control en segundo plano para Samsung Now Bar |

---

## 🚀 Instalación y Puesta en Marcha

### Prerrequisitos
* Flutter SDK (3.22 o superior)
* Android Studio / VS Code
* Clave de API de Google Maps Platform con los siguientes servicios activados:
  * *Maps SDK for Android*
  * *Places API*
  * *Geocoding API*
  * *Directions API*

### Configuración del Entorno

1. **Clonar el repositorio:**
   ```bash
   git clone [https://github.com/TU_USUARIO/ruta_facil.git](https://github.com/TU_USUARIO/ruta_facil.git)
   cd ruta_facil