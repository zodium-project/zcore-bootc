# zcore-bootc

**zcore-bootc** is a minimal, image-based Linux distribution built on **fedora-bootc** .

It is designed to provide a clean, practical foundation for users who want a ready-to-use distro without unnecessary desktop components, while still shipping tools, drivers, and defaults that actually matter.

Built for **bootc-style deployments**, **custom images**, **servers**, **workstations**, and **DIY desktop spins**.

---

## What is zcore ?

zcore is a **base-focused Linux distro** that prioritizes:

- **Minimalism without being barebones**
- **Useful defaults instead of package spam**
- **Multiple curated image variants**
- **Headless-first design**
- **A solid foundation for custom systems**

Unlike traditional desktop distributions, **zcore does not ship with a desktop environment out of the box**.  
It is intentionally built as a **clean base image** for:

- other zodium project images
- headless systems
- containers / bootc-style deployments
- custom image builds

---

## Philosophy

zcore follows a simple rule:

> **Include what is useful. Exclude what is noise.**

That means:

- No random package bloat
- No unnecessary desktop stack in the base image
- No oversized "kitchen sink" installs
- No pretending minimal means unusable

Instead, zcore aims to ship:

- sensible system defaults
- common hardware support where it makes sense
- curated driver and multimedia support
- practical scripts and post-install helpers
- a structure that is easy to extend and maintain

---

## Key Features

- **OCI image based design**
- **No desktop environment out of the box**
- **Built to be extended into custom images or desktop spins**
- **Included system tuning, sysctl, service, and user defaults**
- **Tuned for plug and play hardware support**

---

## Variants

zcore ships in multiple images depending on your hardware .

Current recipe set includes:

- **zcore-mesa** — for desktops with either Intel or AMD gpus
- **zcore-nvidia** — for nvidia gpus (Turing and above)

---

## Intended Use Cases

zcore is best suited for users who want a **clean, opinionated base** rather than a prebuilt full desktop distro.

### Good fit for:

- **Headless systems**
- **Homelab / server installs**
- **bootc / image-based workflows**
- **Custom desktop spins**
- **Gaming-focused custom images**
- **Workstation base images**
- **Power users who want a curated starting point**

### Not intended for:

- Users expecting a complete desktop environment out of the box
- Plug-and-play beginner desktop usage with zero customization
- People who like to manage every package in their system

---

## What's included out of the box ?

zcore by default includes the follow :

- Non-free Multimedia Codecs
- Out-of-tree kernel modules
- Both Podman & Docker
- Modern Cli Tools
- Udev rules for improved hardware support
- Post-install Scripts for user convenience
- Performance oriented system tweaks

zcore's goal is **not** to be the smallest possible image at any cost, goal is to be:
- **practical**
- **predictable**
- **easy to build on**

---

## Why No Desktop Environment ?

Because zcore is meant to be a **base**, not a one-size-fits-all desktop.

Shipping without a desktop environment keeps the base image:

- smaller
- cleaner
- easier to maintain
- easier to customize
- better suited for headless or layered deployments

If you want a desktop, zcore is intended to be the foundation you build it on .
