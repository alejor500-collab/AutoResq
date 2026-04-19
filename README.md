# AutoResQ

> Asistencia en emergencias automotrices — Riobamba, Ecuador

---

## Descripción

AutoResQ es una aplicación móvil Flutter que conecta conductores con problemas vehiculares con técnicos automotrices en Riobamba, Ecuador. Incluye análisis de emergencias con IA, mapa en tiempo real, chat entre conductor y técnico, y sistema de calificaciones.

---

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3.x + Dart 3.x |
| Arquitectura | Clean Architecture + Riverpod |
| Backend | Supabase (Auth + Realtime + PostgreSQL) |
| Mapa | flutter_map + OpenStreetMap + Nominatim |
| IA | OpenAI GPT-4o-mini |
| Navegación | go_router |
| HTTP | dio |
| Fuente | Poppins (Google Fonts) |

---

## Estructura del proyecto

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart       # Paleta de colores
│   │   ├── app_constants.dart    # Constantes globales + placeholders
│   │   └── app_strings.dart      # Textos de la UI
│   ├── errors/
│   │   ├── failures.dart         # Fallas del dominio (Either)
│   │   └── exceptions.dart       # Excepciones de infraestructura
│   ├── network/
│   │   └── dio_client.dart       # Cliente HTTP (OpenAI + Nominatim)
│   ├── router/
│   │   └── app_router.dart       # GoRouter + guardias de rol
│   └── utils/
│       ├── helpers.dart          # Formateo, SnackBars, utilidades
│       └── validators.dart       # Validación de formularios
│
├── features/
│   ├── auth/                     # Login, Register, ForgotPassword, Splash
│   ├── emergency/                # Home Conductor/Técnico, crear emergencia,
│   │                             # estado, activo, historial
│   ├── map/                      # Widget de mapa + proveedor de ubicación
│   ├── chat/                     # Chat en tiempo real (Supabase Realtime)
│   ├── ratings/                  # Calificar técnico / conductor
│   ├── profile/                  # Ver y editar perfil
│   └── admin/                    # Dashboard, usuarios, validación, monitor
│
├── shared/
│   ├── providers/
│   │   ├── auth_provider.dart    # AuthNotifier + authStateProvider
│   │   └── role_provider.dart    # Rol activo (con toggle sin re-login)
│   └── widgets/                  # Botones, campos, shimmer, avatares, estrellas
│
└── main.dart                     # Entry point + Supabase init + tema Poppins
```

---

## Pantallas (21)

### Auth
| # | Pantalla | Ruta |
|---|----------|------|
| 1 | SplashScreen | `/` |
| 2 | LoginScreen | `/login` |
| 3 | RegisterScreen | `/register` |
| 4 | ForgotPasswordScreen | `/forgot-password` |

### Conductor
| # | Pantalla | Ruta |
|---|----------|------|
| 5 | DriverHomeScreen | `/driver/home` |
| 6 | CreateEmergencyScreen | `/driver/emergency/create` |
| 7 | EmergencyStatusScreen | `/driver/emergency/status` |
| 8 | DriverChatScreen | `/driver/chat` |
| 9 | RateServiceScreen | `/driver/rate-service` |

### Técnico
| # | Pantalla | Ruta |
|---|----------|------|
| 10 | TechnicianHomeScreen | `/technician/home` |
| 11 | IncomingRequestSheet | bottom sheet |
| 12 | ActiveServiceScreen | `/technician/active-service` |
| 13 | TechnicianChatScreen | `/technician/chat` |
| 14 | RateDriverScreen | `/technician/rate-driver` |

### Compartidas
| # | Pantalla | Ruta |
|---|----------|------|
| 15 | ProfileScreen | `/profile` |
| 16 | EditProfileScreen | `/profile/edit` |
| 17 | EmergencyHistoryScreen | `/history` |

### Admin
| # | Pantalla | Ruta |
|---|----------|------|
| 18 | AdminDashboardScreen | `/admin` |
| 19 | UserManagementScreen | `/admin/users` |
| 20 | TechnicianValidationScreen | `/admin/validate` |
| 21 | EmergencyMonitorScreen | `/admin/monitor` |

---

## Configuración de placeholders

Edita **`lib/core/constants/app_constants.dart`**:

```dart
// ─── Supabase ────────────────────────────────────────────────────────────────
static const String supabaseUrl = 'https://xxxx.supabase.co';
static const String supabaseAnonKey = 'eyJhbGci...';

// ─── OpenAI ──────────────────────────────────────────────────────────────────
static const String openAiApiKey = 'sk-...';
```

---

## Configuración de Supabase

### 1. Crear tablas

Ejecuta este SQL en el editor de Supabase:

```sql
-- Perfiles de usuario
create table profiles (
  id uuid references auth.users primary key,
  email text,
  name text,
  phone text,
  role text default 'conductor',   -- conductor | tecnico | admin
  avatar_url text,
  rating float default 0,
  total_services int default 0,
  is_available boolean default false,
  is_approved boolean default true,
  specialty text,
  lat float,
  lng float,
  created_at timestamptz default now()
);

-- Emergencias
create table emergencies (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid references profiles(id),
  driver_name text,
  driver_rating float default 0,
  technician_id uuid references profiles(id),
  technician_name text,
  technician_phone text,
  technician_lat float,
  technician_lng float,
  description text not null,
  status text default 'pendiente',
  tech_status text,
  lat float not null,
  lng float not null,
  address text,
  ai_analysis jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz
);

-- Mensajes de chat
create table messages (
  id uuid primary key default gen_random_uuid(),
  emergency_id uuid references emergencies(id) on delete cascade,
  sender_id uuid references profiles(id),
  sender_name text,
  content text not null,
  is_read boolean default false,
  created_at timestamptz default now()
);

-- Calificaciones
create table ratings (
  id uuid primary key default gen_random_uuid(),
  emergency_id uuid references emergencies(id),
  rater_id uuid references profiles(id),
  rated_id uuid references profiles(id),
  stars int check (stars >= 1 and stars <= 5),
  review text,
  created_at timestamptz default now()
);
```

### 2. Row Level Security (RLS)

```sql
-- Habilitar RLS
alter table profiles enable row level security;
alter table emergencies enable row level security;
alter table messages enable row level security;
alter table ratings enable row level security;

-- Políticas básicas (ajustar según necesidad)
create policy "profiles_public" on profiles for select using (true);
create policy "profiles_own" on profiles for update using (auth.uid() = id);
create policy "emergencies_all" on emergencies for all using (true);
create policy "messages_all" on messages for all using (true);
create policy "ratings_all" on ratings for all using (true);
```

### 3. Trigger para crear perfil al registrarse

```sql
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, name, phone, role)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'role', 'conductor')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();
```

---

## Instalación

```bash
# 1. Clonar / tener el proyecto Flutter vacío
cd AutoResQ

# 2. Instalar dependencias
flutter pub get

# 3. Configurar placeholders en app_constants.dart

# 4. Ejecutar en dispositivo o emulador
flutter run
```

---

## Permisos requeridos

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>AutoResQ necesita tu ubicación para encontrar técnicos cercanos</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>AutoResQ usa tu ubicación para mostrarte al mapa</string>
```

---

## Diseño

| Token | Valor |
|-------|-------|
| Color primario | `#E53935` (rojo) |
| Color secundario | `#1E88E5` (azul) |
| Fondo | `#FFFFFF` |
| Superficie | `#F5F5F5` |
| Fuente | Poppins |
| Radio tarjetas | 12px |
| Radio botones | 8px |
| Grilla base | 8px |
| Touch target mínimo | 44px |

---

## Licencia

MIT — Proyecto académico / comercial para Riobamba, Ecuador.
