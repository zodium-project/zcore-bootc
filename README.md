zcore-bootc images are still in beta , dont use them rn. ( release 1 is planned for 17/3/2026)

to-do :
1. 
2. add old-nvidia cards support (580-lts image).
3. downstream opinionated defaults + upstream universal defaults.
4. add framework laptop support ( use bazzite implementation as reference )
5. add MS-surface laptops support ( linux-surface ?) {low priority}
6. make custom asus-laptop iso ( asus-linux ?) {low priority}
7. make apple-silicon iso ? ( asahi like ? ) {very low priority}
8. fix experimental-tools ( dgpu-run & prime-run )
9. depricate prime-run ? rework dgpu-run ?
10. add zjust & commands like : tpm2-auto-unlock , update , mok-enroll , windows-container , btrfs-compression-level , rebase , install-razer-support
11. 
12. add openrazer akmods ??
13. use cachyos kernel & sign it ? or use linux-zen/liqorx and sign it ? or use OGC/Bazzite kernel and sign it ?
14. add cachyos & OGC patches to base (needed/Qol only , no opinionated ones)
15. 
16. 
17. make a custom copr for existing packages instead of directly placing them /usr/bin .
18. 
19. make a new branch ( unstable & rename current one to stable)

Current Release : Snapshot 7 (usable but not 100% stable)