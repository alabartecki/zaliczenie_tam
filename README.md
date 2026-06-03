# Metropolitan Museum of Art – Flutter App

Mobilna aplikacja Flutter wyświetlająca dzieła sztuki z kolekcji Metropolitan Museum of Art (Nowy Jork) przy użyciu publicznego REST API MET.

## Opis aplikacji

Aplikacja umożliwia przeglądanie, wyszukiwanie i zapisywanie ulubionych dzieł sztuki z jednego z największych muzeów na świecie. Dane pobierane są z oficjalnego, bezpłatnego API The Metropolitan Museum of Art.

## Ekrany

- **Explore** – lista dzieł sztuki filtrowana według preferencji użytkownika (departament, liczba wyników)
- **Trending** – dzisiejsze top 20 wyróżnionych dzieł muzeum, odświeżane raz dziennie
- **Favourites** – osobista lista ulubionych z możliwością zmiany kolejności (drag & drop)
- **Detail** – szczegółowy widok dzieła: zdjęcie, opis, technika, wymiary, okres, galeria dodatkowych zdjęć
- **Settings** – ustawienia pobierania: liczba dzieł, filtr departamentu, dodatkowe informacje

## Funkcjonalności

- Przeglądanie dzieł sztuki z Metropolitan Museum of Art API
- Ekran trendów z top 20 wyróżnionych dzieł (cache dzienny)
- Dodawanie dzieł do ulubionych i ręczne sortowanie listy
- Ekran ustawień: filtrowanie po departamencie, liczba wyników, dodatkowe metadane
- Tryb offline – pełna dostępność dzięki lokalnej bazie danych Hive
- Pull-to-refresh – ręczne odświeżenie danych z API
- Firebase Analytics – śledzenie zdarzeń: otwarcie dzieła, dodanie do ulubionych, zmiana zakładki
- Firebase Crashlytics – automatyczne raportowanie błędów

## REST API

Aplikacja korzysta z [The Metropolitan Museum of Art Collection API](https://metmuseum.github.io/):

| Endpoint | Zastosowanie |
|---|---|
| `GET /search` | Pobieranie listy ID dzieł (z filtrowaniem) |
| `GET /objects/{id}` | Pobieranie szczegółów i opisu dzieła |

## Technologie

- Flutter / Dart
- Hive – lokalna baza danych (offline cache)
- Firebase Analytics + Crashlytics
- cached_network_image – cachowanie obrazów sieciowych
- http – zapytania REST
