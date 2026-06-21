# 🏎️ FaisTrack

> Automatically track your drives. Compete with friends. Build your garage.

**FaisTrack** is a bilingual (Arabic/English) iOS app for automatic drive tracking, built for the GCC and global market.

## Features
- 🚗 **Smart Garage** — Add and manage your cars with full specs and mods
- 📍 **Auto Drive Tracking** — Detects drives automatically via CoreMotion + GPS
- 📊 **Statistics** — Per-car stats, milestones, safety scores (Pro)
- 👥 **Friends** — Compare drives and stats with friends
- 🏆 **Leaderboard** — Global and friends rankings
- 🚘 **CarPlay** — Live speed display while driving
- 🌐 **Bilingual** — Full Arabic RTL + English support

## Tech Stack
- **Platform:** iOS 15+ (SwiftUI)
- **Backend:** Firebase (Auth, Firestore, Storage, FCM)
- **Maps:** Google Maps SDK
- **CI/CD:** Codemagic
- **Payments:** StoreKit 2

## Setup
1. Clone this repo
2. Add `GoogleService-Info.plist` to `FaisTrack/Supporting/`
3. Add your Google Maps API key in `AppDelegate.swift`
4. Run `pod install`
5. Open `FaisTrack.xcworkspace`

## Bundle ID
`com.faistrack.app`

## Developer
Built by Faisal AlBulushi — [faistune.com](https://faistune.com)
