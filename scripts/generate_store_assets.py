"""Create Google Play listing art from the checked-in StokPilot icon."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "store_assets"
OUT.mkdir(exist_ok=True)

icon = Image.open(ROOT / "assets/icons/stokpilot_icon.png").convert("RGB")
icon.resize((512, 512), Image.Resampling.LANCZOS).save(
    OUT / "google_play_icon_512.png", optimize=True
)

banner = Image.new("RGB", (1024, 500), "#0b292e")
draw = ImageDraw.Draw(banner)
draw.rounded_rectangle((32, 32, 992, 468), radius=42, fill="#103d42")
banner.paste(icon.resize((370, 370), Image.Resampling.LANCZOS), (65, 65))

font_dir = Path("C:/Windows/Fonts")
title = ImageFont.truetype(str(font_dir / "segoeuib.ttf"), 64)
subtitle = ImageFont.truetype(str(font_dir / "segoeui.ttf"), 29)
draw.text((470, 178), "StokPilot", font=title, fill="#eefaf6")
draw.text((473, 268), "Stok, cari ve tedarik yönetimi", font=subtitle, fill="#bbddd5")
banner.save(OUT / "google_play_feature_1024x500.png", optimize=True)
