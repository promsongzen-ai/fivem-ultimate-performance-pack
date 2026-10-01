FiveM Ultimate Performance Optimization Pack

Purpose:
This pack is a conservative, reversible Windows 11 optimization system for the Acer Nitro V 15 with Intel Core i5-12400F and NVIDIA GeForce RTX 3050 Laptop GPU.

Core principles:
- Do not force CPU or GPU usage to 100%.
- Do not use Realtime priority or unsafe affinity settings.
- Do not disable Windows security or critical Windows services.
- Do not use unsupported or placebo Registry tricks.
- Prefer measurable improvements in frame-time stability, 1% lows, and input responsiveness.
- If a tweak is uncertain, it is marked A/B TEST ONLY.

This pack is designed to improve:
- stable FPS
- smoother frame pacing
- lower micro-stutter
- better 1% and 0.1% lows
- lower input latency
- better system stability

Suggested workflow:
1. Run 00-BACKUP.ps1
2. Run 01-DIAGNOSTIC.ps1
3. Review the report.
4. Run 02-WINDOWS-GAMING.ps1
5. Run 03-POWER-CPU.ps1
6. Run 04-GPU.ps1
7. Run 05-INPUT.ps1
8. Run 06-NETWORK.ps1
9. Run 07-REGISTRY.ps1
10. Run 08-BACKGROUND.ps1
11. Run 09-FIVEM.ps1
12. Run APPLY-ALL.ps1 for the automated safe set
13. Run 10-VERIFY.ps1
14. Run RESTORE-ALL.ps1 if needed

Administrator requirement:
Some scripts need local Administrator rights.
Run PowerShell as Administrator.

Safe rollback:
Always use the backup directory created by 00-BACKUP.ps1 or RESTORE-ALL.ps1.
Do not restore unrelated settings.

Testing guidance:
- Use the same FiveM server and location.
- Use the same resolution and graphics settings.
- Compare average FPS, 1% low, 0.1% low, frame-time, and input responsiveness before and after each change.
- Only keep changes that improve smoothness and stability.

Important note:
No optimization can guarantee a specific FPS number. This pack focuses on stable performance and reduced stutter rather than fake benchmark claims.
