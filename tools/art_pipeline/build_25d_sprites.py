#!/usr/bin/env python3
"""
HD-2D / RO 2.5D Anime Sprite Asset Generator (SVG -> Godot 4 native ThorVG)
Generates clean, high-DPI, bold-inked anime cel-shaded 2.5D sprites matching
the Koutetsujou concept art & Blue Archive chibi aesthetic:
  - assets/sprites/characters/{reina_ar,chisa_smg,lily_sg}_body.svg
  - assets/sprites/characters/{reina_ar,chisa_smg,lily_sg}_halo.svg
  - assets/sprites/weapons/{ar_rifle,smg_compact,sg_heavy}.svg
  - assets/sprites/ruins/{building_a,building_b,overpass,wrecked_car,tactical_cover,supply_crate,streetlight}.svg
"""

import os

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPRITE_DIR = os.path.join(ROOT_DIR, "assets", "sprites")
CHAR_DIR = os.path.join(SPRITE_DIR, "characters")
WEAP_DIR = os.path.join(SPRITE_DIR, "weapons")
RUIN_DIR = os.path.join(SPRITE_DIR, "ruins")

for d in (CHAR_DIR, WEAP_DIR, RUIN_DIR):
    os.makedirs(d, exist_ok=True)


def save_svg(path: str, content: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")


# ============================================================================
# 1. BLUE ARCHIVE STYLE 2D CHIBI CHARACTERS (2.5-HEAD PROPORTIONS, 512x640)
# ============================================================================

def build_chibi_character_svg(cfg: dict) -> str:
    """
    Build a high-detail 2.5-head-tall Blue Archive SD anime chibi sprite facing 3/4 right.
    Crisp #1C1A29 anime ink outlines, cel-shaded gradients, glossy multi-layer anime eyes,
    hair highlight ribbon, tactical academy outfit, and boots.
    """
    cid = cfg["id"]
    ink = "#1B1928"
    hair_base = cfg["hair_base"]
    hair_dark = cfg["hair_dark"]
    hair_hi = cfg["hair_hi"]
    eye_top = cfg["eye_top"]
    eye_bot = cfg["eye_bot"]
    eye_pupil = cfg["eye_pupil"]
    jacket_main = cfg["jacket_main"]
    jacket_shadow = cfg["jacket_shadow"]
    accent = cfg["accent"]
    accent_dark = cfg["accent_dark"]
    skirt_main = cfg["skirt_main"]
    skirt_shadow = cfg["skirt_shadow"]
    sock_col = cfg["sock_col"]
    boot_col = cfg["boot_col"]
    hair_style = cfg["hair_style"]

    # Back hair silhouette tailored per character
    if hair_style == "ponytail":
        back_hair = f"""
        <!-- Flowing high ponytail behind head -->
        <path d="M 215 160 C 120 130, 82 225, 102 335 C 122 385, 162 418, 182 405
                 C 155 360, 152 295, 175 255 C 188 230, 208 210, 224 195 Z"
              fill="url(#hairGrad_{cid})" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
        <path d="M 155 188 C 124 228, 120 296, 146 364" fill="none" stroke="{hair_dark}" stroke-width="5" stroke-linecap="round" opacity="0.65"/>
        <!-- Ponytail ribbon -->
        <path d="M 192 150 L 222 162 L 210 192 L 180 176 Z" fill="{accent}" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
        <path d="M 188 176 L 154 220 L 178 228 L 202 184 Z" fill="{accent_dark}" stroke="{ink}" stroke-width="5" stroke-linejoin="round"/>
        <!-- Back neck hair -->
        <path d="M 170 250 C 156 320, 170 365, 208 380 L 320 375 C 344 350, 348 300, 336 250 Z"
              fill="{hair_dark}" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
        """
    elif hair_style == "bob_goggles":
        back_hair = f"""
        <!-- Choppy dark-navy tactical bob back hair -->
        <path d="M 156 205 C 130 270, 134 338, 168 378 L 194 352 L 208 386
                 L 318 384 L 336 355 L 358 372 C 378 326, 376 256, 350 202 Z"
              fill="url(#hairGrad_{cid})" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
        """
    else:  # twintails
        back_hair = f"""
        <!-- Left & Right fluffy golden twintails -->
        <path d="M 164 180 C 90 190, 62 285, 92 390 C 106 426, 146 436, 160 408
                 C 138 358, 142 292, 174 242 Z"
              fill="url(#hairGrad_{cid})" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
        <path d="M 346 184 C 414 202, 434 295, 404 392 C 390 426, 356 430, 346 402
                 C 364 352, 362 292, 336 244 Z"
              fill="url(#hairGrad_{cid})" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
        <!-- Crimson twintail ribbons -->
        <ellipse cx="164" cy="196" rx="18" ry="13" transform="rotate(-24 164 196)" fill="{accent}" stroke="{ink}" stroke-width="6"/>
        <ellipse cx="348" cy="198" rx="18" ry="13" transform="rotate(24 348 198)" fill="{accent}" stroke="{ink}" stroke-width="6"/>
        """

    # Forehead accessory (Chisa's amber goggles, Reina's ahoge, Lily's ribbon clip)
    if hair_style == "bob_goggles":
        head_acc = f"""
        <!-- Tactical Engineer Goggles on forehead -->
        <path d="M 156 176 Q 260 144 360 178" fill="none" stroke="#363B48" stroke-width="24" stroke-linecap="round"/>
        <path d="M 156 176 Q 260 144 360 178" fill="none" stroke="{ink}" stroke-width="6" stroke-linecap="round"/>
        <ellipse cx="222" cy="166" rx="34" ry="24" fill="#3B4252" stroke="{ink}" stroke-width="7"/>
        <ellipse cx="222" cy="166" rx="24" ry="16" fill="url(#goggleGrad)" stroke="{ink}" stroke-width="4"/>
        <ellipse cx="215" cy="159" rx="8" ry="4" fill="#FFF7D6" opacity="0.88"/>
        <ellipse cx="304" cy="168" rx="34" ry="24" fill="#3B4252" stroke="{ink}" stroke-width="7"/>
        <ellipse cx="304" cy="168" rx="24" ry="16" fill="url(#goggleGrad)" stroke="{ink}" stroke-width="4"/>
        <ellipse cx="297" cy="161" rx="8" ry="4" fill="#FFF7D6" opacity="0.88"/>
        <rect x="253" y="160" width="20" height="12" rx="4" fill="#2A2F3B" stroke="{ink}" stroke-width="5"/>
        """
    elif hair_style == "ponytail":
        head_acc = f"""
        <!-- Cute ahoge cowlick + tactical hairclip -->
        <path d="M 250 112 C 248 76, 286 68, 304 92 C 282 90, 268 100, 264 114 Z"
              fill="{hair_base}" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
        <rect x="190" y="216" width="28" height="10" rx="4" transform="rotate(-14 190 216)"
              fill="{accent}" stroke="{ink}" stroke-width="4.5"/>
        """
    else:
        head_acc = f"""
        <!-- Cute ahoge + twin hairpins -->
        <path d="M 254 114 C 244 78, 278 66, 294 88 C 276 88, 268 100, 266 116 Z"
              fill="{hair_base}" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
        <path d="M 192 214 L 222 224 M 196 226 L 224 212" stroke="{accent}" stroke-width="7" stroke-linecap="round"/>
        """

    return f"""
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="640" viewBox="0 0 512 640">
  <defs>
    <linearGradient id="hairGrad_{cid}" x1="0" y1="0" x2="0.2" y2="1">
      <stop offset="0%" stop-color="{hair_hi}"/>
      <stop offset="48%" stop-color="{hair_base}"/>
      <stop offset="100%" stop-color="{hair_dark}"/>
    </linearGradient>
    <linearGradient id="skinGrad_{cid}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFF5EE"/>
      <stop offset="72%" stop-color="#FCE4D4"/>
      <stop offset="100%" stop-color="#EFC8B4"/>
    </linearGradient>
    <linearGradient id="eyeGrad_{cid}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{eye_top}"/>
      <stop offset="55%" stop-color="{eye_pupil}"/>
      <stop offset="100%" stop-color="{eye_bot}"/>
    </linearGradient>
    <linearGradient id="jacketGrad_{cid}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="{jacket_main}"/>
      <stop offset="100%" stop-color="{jacket_shadow}"/>
    </linearGradient>
    <linearGradient id="skirtGrad_{cid}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{skirt_main}"/>
      <stop offset="100%" stop-color="{skirt_shadow}"/>
    </linearGradient>
    <linearGradient id="goggleGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFE066"/>
      <stop offset="55%" stop-color="#F59E0B"/>
      <stop offset="100%" stop-color="#B45309"/>
    </linearGradient>
  </defs>

  {back_hair}

  <!-- ================= LEGS & COMBAT BOOTS ================= -->
  <!-- Left leg (back) -->
  <path d="M 218 485 L 210 554 L 244 554 L 248 485 Z" fill="url(#skinGrad_{cid})" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
  <path d="M 209 528 L 207 568 L 245 568 L 246 528 Z" fill="{sock_col}" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
  <!-- Left combat boot -->
  <path d="M 204 558 L 248 558 L 254 596 C 255 606, 248 612, 236 612 L 198 612 C 190 612, 188 600, 195 590 Z"
        fill="{boot_col}" stroke="{ink}" stroke-width="7.5" stroke-linejoin="round"/>
  <path d="M 196 600 L 252 600" stroke="#101018" stroke-width="6"/>

  <!-- Right leg (front) -->
  <path d="M 268 485 L 274 554 L 308 554 L 300 485 Z" fill="url(#skinGrad_{cid})" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
  <path d="M 272 528 L 274 568 L 311 568 L 308 528 Z" fill="{sock_col}" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
  <!-- Right combat boot -->
  <path d="M 271 558 L 315 558 L 329 594 C 333 605, 326 612, 314 612 L 273 612 C 266 612, 265 602, 268 592 Z"
        fill="{boot_col}" stroke="{ink}" stroke-width="7.5" stroke-linejoin="round"/>
  <path d="M 269 600 L 328 600" stroke="#101018" stroke-width="6"/>
  <!-- Boot accent buckles -->
  <rect x="282" y="566" width="22" height="8" rx="3" fill="{accent}" stroke="{ink}" stroke-width="4"/>
  <rect x="214" y="566" width="22" height="8" rx="3" fill="{accent}" stroke="{ink}" stroke-width="4"/>

  <!-- ================= PLEATED TACTICAL SKIRT & BELT ================= -->
  <path d="M 204 440 L 316 440 L 342 508 C 306 522, 214 522, 178 508 Z"
        fill="url(#skirtGrad_{cid})" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <!-- Skirt pleats + trim hem -->
  <path d="M 224 452 L 212 512 M 258 452 L 258 515 M 292 452 L 305 512"
        stroke="{ink}" stroke-width="5" stroke-linecap="round" opacity="0.55"/>
  <path d="M 183 498 C 218 511, 302 511, 337 498" fill="none" stroke="{accent}" stroke-width="7" stroke-linecap="round"/>

  <!-- Tactical utility belt & side pouches -->
  <rect x="200" y="428" width="120" height="22" rx="7" fill="#2A2F3D" stroke="{ink}" stroke-width="6.5"/>
  <rect x="247" y="426" width="26" height="26" rx="5" fill="{accent}" stroke="{ink}" stroke-width="5.5"/>
  <rect x="184" y="438" width="24" height="30" rx="5" fill="#3B4254" stroke="{ink}" stroke-width="6"/>
  <rect x="312" y="438" width="24" height="30" rx="5" fill="#3B4254" stroke="{ink}" stroke-width="6"/>

  <!-- ================= TORSO & TACTICAL ACADEMY JACKET ================= -->
  <!-- Back right arm holding ready -->
  <path d="M 308 368 C 338 386, 348 418, 342 444 L 314 446 C 314 422, 304 402, 294 390 Z"
        fill="{jacket_shadow}" stroke="{ink}" stroke-width="7.5" stroke-linejoin="round"/>
  <circle cx="328" cy="446" r="15" fill="url(#skinGrad_{cid})" stroke="{ink}" stroke-width="6.5"/>

  <!-- Jacket body -->
  <path d="M 206 356 C 232 346, 288 346, 314 356 L 326 436 L 194 436 Z"
        fill="url(#jacketGrad_{cid})" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <!-- Crisp collar & tactical tie/ribbon -->
  <path d="M 222 350 L 260 392 L 298 350 L 284 344 L 260 370 L 236 344 Z"
        fill="#FFFFFF" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <path d="M 250 376 L 270 376 L 276 420 L 260 432 L 244 420 Z"
        fill="{accent}" stroke="{ink}" stroke-width="5.5" stroke-linejoin="round"/>
  <!-- Shoulder tactical strap / badge -->
  <path d="M 202 362 L 232 356 L 228 378 L 198 382 Z" fill="{accent}" stroke="{ink}" stroke-width="5" stroke-linejoin="round"/>

  <!-- Left front arm -->
  <path d="M 206 368 C 176 388, 174 422, 198 446 L 224 438 C 212 418, 212 398, 224 388 Z"
        fill="url(#jacketGrad_{cid})" stroke="{ink}" stroke-width="7.5" stroke-linejoin="round"/>
  <circle cx="212" cy="444" r="15" fill="url(#skinGrad_{cid})" stroke="{ink}" stroke-width="6.5"/>

  <!-- ================= ANIME CHIBI HEAD & EXPRESSIVE FACE ================= -->
  <!-- Neck -->
  <rect x="244" y="330" width="32" height="30" rx="10" fill="#EFC8B4" stroke="{ink}" stroke-width="6.5"/>

  <!-- Cute soft-round anime face contour (3/4 right tilt) -->
  <path d="M 164 218 C 160 150, 206 122, 262 122 C 322 122, 360 154, 356 226
           C 354 288, 336 334, 274 348 C 210 352, 168 308, 164 218 Z"
        fill="url(#skinGrad_{cid})" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>

  <!-- Soft pink anime cheek blush + tiny diagonal blush marks -->
  <ellipse cx="204" cy="296" rx="22" ry="12" fill="#FF8FA3" opacity="0.48"/>
  <ellipse cx="322" cy="296" rx="20" ry="11" fill="#FF8FA3" opacity="0.48"/>
  <path d="M 196 294 L 201 300 M 206 294 L 211 300 M 315 294 L 320 300 M 325 294 L 330 300"
        stroke="#F46B84" stroke-width="3" stroke-linecap="round" opacity="0.65"/>

  <!-- Glossy Blue Archive Anime Eyes (Left & Right) -->
  <!-- Left Eye -->
  <ellipse cx="222" cy="264" rx="26" ry="30" fill="#FFFFFF" stroke="{ink}" stroke-width="4.5"/>
  <ellipse cx="226" cy="266" rx="20" ry="25" fill="url(#eyeGrad_{cid})"/>
  <ellipse cx="227" cy="268" rx="10" ry="13" fill="{ink}"/>
  <ellipse cx="227" cy="282" rx="12" ry="6" fill="{eye_bot}" opacity="0.85"/>
  <circle cx="216" cy="254" r="7.5" fill="#FFFFFF"/>
  <circle cx="236" cy="276" r="4" fill="#FFFFFF"/>
  <!-- Bold upper anime eyelash -->
  <path d="M 191 250 C 204 232, 238 232, 250 248" fill="none" stroke="{ink}" stroke-width="9.5" stroke-linecap="round"/>

  <!-- Right Eye (slightly narrower for 3/4 right perspective) -->
  <ellipse cx="308" cy="264" rx="23" ry="29" fill="#FFFFFF" stroke="{ink}" stroke-width="4.5"/>
  <ellipse cx="310" cy="266" rx="18" ry="24" fill="url(#eyeGrad_{cid})"/>
  <ellipse cx="311" cy="268" rx="9" ry="12.5" fill="{ink}"/>
  <ellipse cx="310" cy="282" rx="10" ry="5.5" fill="{eye_bot}" opacity="0.85"/>
  <circle cx="301" cy="254" r="7" fill="#FFFFFF"/>
  <circle cx="318" cy="276" r="3.8" fill="#FFFFFF"/>
  <path d="M 284 248 C 296 232, 326 232, 336 250" fill="none" stroke="{ink}" stroke-width="9.5" stroke-linecap="round"/>

  <!-- Tiny cute anime nose dot & confident smile -->
  <circle cx="272" cy="288" r="2.6" fill="#C98D7B"/>
  <path d="M 255 308 Q 268 320 284 307" fill="none" stroke="#9B4E4E" stroke-width="5" stroke-linecap="round"/>

  <!-- ================= FRONT HAIR CROWN, BANGS & SIDE LOCKS ================= -->
  <!-- Main hair crown dome -->
  <path d="M 152 224 C 148 138, 198 106, 260 106 C 326 106, 370 144, 366 226
           C 362 260, 354 304, 344 334 C 338 296, 344 252, 338 228
           L 322 252 L 308 214 L 290 256 L 270 212 L 248 258 L 230 214 L 208 256 L 190 220
           C 180 258, 182 308, 174 344 C 158 310, 152 268, 152 224 Z"
        fill="url(#hairGrad_{cid})" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>

  <!-- Glossy anime halo-ribbon hair highlight across crown! -->
  <path d="M 184 186 Q 222 164 258 180 Q 296 164 336 186"
        fill="none" stroke="{hair_hi}" stroke-width="14" stroke-linecap="round" opacity="0.82"/>
  <path d="M 192 184 Q 224 166 258 180 Q 296 166 330 184"
        fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" opacity="0.65"/>

  <!-- Expressive eyebrows over bangs -->
  <path d="M 206 224 Q 224 218 240 224" fill="none" stroke="{ink}" stroke-width="4.5" stroke-linecap="round" opacity="0.75"/>
  <path d="M 294 224 Q 310 218 326 224" fill="none" stroke="{ink}" stroke-width="4.5" stroke-linecap="round" opacity="0.75"/>

  {head_acc}
</svg>
"""


def build_halo_svg(style: str, col_main: str, col_glow: str) -> str:
    if style == "ring_star":
        inner = f"""
        <ellipse cx="128" cy="64" rx="92" ry="26" fill="none" stroke="{col_glow}" stroke-width="18" opacity="0.38"/>
        <ellipse cx="128" cy="64" rx="92" ry="26" fill="none" stroke="{col_main}" stroke-width="8"/>
        <ellipse cx="128" cy="64" rx="64" ry="16" fill="none" stroke="#FFFFFF" stroke-width="4.5"/>
        <path d="M 128 24 L 136 44 L 128 52 L 120 44 Z M 128 104 L 136 84 L 128 76 L 120 84 Z
                 M 26 64 L 54 58 L 62 64 L 54 70 Z M 230 64 L 202 58 L 194 64 L 202 70 Z"
              fill="#FFFFFF" stroke="{col_main}" stroke-width="3"/>
        """
    elif style == "gear":
        inner = f"""
        <ellipse cx="128" cy="64" rx="90" ry="26" fill="none" stroke="{col_glow}" stroke-width="18" opacity="0.38"/>
        <ellipse cx="128" cy="64" rx="84" ry="24" fill="none" stroke="{col_main}" stroke-width="9" stroke-dasharray="20 10"/>
        <ellipse cx="128" cy="64" rx="58" ry="15" fill="none" stroke="#FFF6D6" stroke-width="5"/>
        <circle cx="128" cy="39" r="6" fill="#FFFFFF"/>
        <circle cx="128" cy="89" r="6" fill="#FFFFFF"/>
        <circle cx="44" cy="64" r="6" fill="#FFFFFF"/>
        <circle cx="212" cy="64" r="6" fill="#FFFFFF"/>
        """
    else:  # crosshair
        inner = f"""
        <ellipse cx="128" cy="64" rx="92" ry="26" fill="none" stroke="{col_glow}" stroke-width="18" opacity="0.38"/>
        <ellipse cx="128" cy="64" rx="88" ry="25" fill="none" stroke="{col_main}" stroke-width="8"/>
        <ellipse cx="128" cy="64" rx="46" ry="13" fill="none" stroke="#FFFFFF" stroke-width="4.5"/>
        <path d="M 128 20 L 128 46 M 128 82 L 128 108 M 18 64 L 66 64 M 190 64 L 238 64"
              stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>
        """
    return f"""
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="128" viewBox="0 0 256 128">
  {inner}
</svg>
"""


# ============================================================================
# 2. INDEPENDENT ROTATING TACTICAL WEAPON SPRITES (320x128, pointing +X right)
# ============================================================================

def build_weapons() -> None:
    ink = "#181A24"
    # 1. Tactical Assault Rifle (Reina AR)
    save_svg(os.path.join(WEAP_DIR, "ar_rifle.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="128" viewBox="0 0 320 128">
  <!-- Buttstock -->
  <path d="M 14 48 L 86 44 L 86 76 L 20 88 Z" fill="#2B3242" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <!-- Upper & Lower Receiver -->
  <rect x="82" y="40" width="118" height="36" rx="6" fill="#3D465A" stroke="{ink}" stroke-width="6"/>
  <rect x="92" y="46" width="98" height="10" rx="3" fill="#67748E"/>
  <!-- Tactical Handguard & Barrel -->
  <rect x="196" y="44" width="66" height="24" rx="4" fill="#2A303E" stroke="{ink}" stroke-width="6"/>
  <rect x="260" y="51" width="46" height="11" rx="3" fill="#525D73" stroke="{ink}" stroke-width="5"/>
  <!-- Muzzle brake -->
  <rect x="296" y="47" width="16" height="19" rx="3" fill="#252A36" stroke="{ink}" stroke-width="5"/>
  <!-- Curved Magazine & Grip -->
  <path d="M 156 76 L 180 76 L 194 116 L 166 118 Z" fill="#242936" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <path d="M 104 76 L 126 76 L 114 110 L 94 106 Z" fill="#242936" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <!-- Holographic Sight with Cyan Glow -->
  <rect x="116" y="20" width="52" height="22" rx="5" fill="#252B38" stroke="{ink}" stroke-width="5.5"/>
  <rect x="128" y="25" width="28" height="10" rx="2" fill="#4AE8FF"/>
  <!-- Cyan Tactical Accent Strip -->
  <rect x="206" y="52" width="42" height="7" rx="2" fill="#4AE8FF"/>
</svg>
""")

    # 2. Compact Submachine Gun (Chisa SMG)
    save_svg(os.path.join(WEAP_DIR, "smg_compact.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="128" viewBox="0 0 320 128">
  <!-- Wire Folding Stock -->
  <path d="M 38 48 L 92 48 M 38 72 L 92 68 M 38 44 L 38 78" stroke="#363D4D" stroke-width="8" stroke-linecap="round"/>
  <!-- Compact Receiver -->
  <rect x="88" y="38" width="136" height="42" rx="8" fill="#454E60" stroke="{ink}" stroke-width="6"/>
  <rect x="98" y="45" width="114" height="12" rx="3" fill="#6F7B91"/>
  <!-- Suppressor Barrel -->
  <rect x="222" y="45" width="76" height="22" rx="6" fill="#2A303C" stroke="{ink}" stroke-width="6"/>
  <!-- Vertical Extended SMG Mag + Grip -->
  <rect x="172" y="78" width="22" height="44" rx="4" fill="#262C38" stroke="{ink}" stroke-width="6"/>
  <path d="M 112 78 L 136 78 L 126 112 L 104 108 Z" fill="#262C38" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <!-- Reflex Sight + Amber Accent -->
  <path d="M 134 22 L 178 22 L 184 38 L 128 38 Z" fill="#2C3240" stroke="{ink}" stroke-width="5.5" stroke-linejoin="round"/>
  <rect x="142" y="26" width="28" height="8" rx="2" fill="#FFB830"/>
  <rect x="108" y="62" width="52" height="8" rx="3" fill="#FFB830"/>
</svg>
""")

    # 3. Heavy Tactical Shotgun (Lily SG)
    save_svg(os.path.join(WEAP_DIR, "sg_heavy.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="128" viewBox="0 0 320 128">
  <!-- Heavy Stock -->
  <path d="M 14 54 L 84 44 L 84 82 L 18 96 Z" fill="#2A2630" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <!-- Chunky Tactical Receiver -->
  <rect x="78" y="38" width="116" height="44" rx="7" fill="#3B3642" stroke="{ink}" stroke-width="6"/>
  <!-- Heavy Over-Under Double Tube Barrel -->
  <rect x="190" y="40" width="116" height="18" rx="4" fill="#52586A" stroke="{ink}" stroke-width="6"/>
  <rect x="190" y="60" width="102" height="16" rx="4" fill="#2A2E3A" stroke="{ink}" stroke-width="6"/>
  <!-- Pump Forend with Crimson Ribbing -->
  <rect x="198" y="58" width="66" height="24" rx="5" fill="#C92A3E" stroke="{ink}" stroke-width="6"/>
  <path d="M 212 62 L 212 78 M 228 62 L 228 78 M 244 62 L 244 78" stroke="{ink}" stroke-width="4.5"/>
  <!-- Drum / Box Shell Caddy & Pistol Grip -->
  <rect x="132" y="80" width="44" height="34" rx="8" fill="#26242E" stroke="{ink}" stroke-width="6"/>
  <path d="M 92 80 L 116 80 L 104 114 L 82 110 Z" fill="#26242E" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <!-- Red Dot Sight + Crimson Stripe -->
  <rect x="108" y="20" width="46" height="18" rx="4" fill="#26242E" stroke="{ink}" stroke-width="5"/>
  <rect x="118" y="25" width="26" height="7" rx="2" fill="#FF3B5C"/>
  <rect x="92" y="54" width="84" height="9" rx="3" fill="#FF3B5C"/>
</svg>
""")


# ============================================================================
# 3. HAND-INKED ANIME 2.5D RUINS PROPS (GFL2 DUSK PALETTE MATCHING KOUTETSUJOU)
# ============================================================================

def build_ruins_sprites() -> None:
    ink = "#1A1E2A"

    # 1. Collapsed Brutalist Building A (Towering jagged silhouette, 640x768)
    save_svg(os.path.join(RUIN_DIR, "building_a.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="768" viewBox="0 0 640 768">
  <defs>
    <linearGradient id="bldgA_front" x1="0" y1="0" x2="0.3" y2="1">
      <stop offset="0%" stop-color="#8B99AE"/>
      <stop offset="55%" stop-color="#606E82"/>
      <stop offset="100%" stop-color="#3E4858"/>
    </linearGradient>
    <linearGradient id="bldgA_side" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#566378"/>
      <stop offset="100%" stop-color="#2D3544"/>
    </linearGradient>
  </defs>
  <!-- Exposed bent steel rebar along jagged top -->
  <path d="M 130 164 L 118 82 M 162 152 L 178 66 M 214 118 L 204 38 M 256 128 L 284 52
           M 332 184 L 358 104 M 392 222 L 424 148 M 456 266 L 492 206"
        stroke="#2A2628" stroke-width="7" stroke-linecap="round"/>
  <!-- Shaded 3/4 Right Side Wall -->
  <polygon points="418,228 564,284 564,752 418,752" fill="url(#bldgA_side)" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <!-- Main Front Jagged Brutalist Concrete Facade -->
  <polygon points="74,752 74,178 158,150 218,108 288,136 336,192 418,228 418,752"
           fill="url(#bldgA_front)" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <!-- Warm sunset rim catchlight on jagged left/top edges -->
  <polyline points="78,748 78,180 158,154 218,112 288,140" fill="none" stroke="#F4B27A" stroke-width="6" opacity="0.72"/>
  <!-- Concrete floor slab bands -->
  <g stroke="{ink}" stroke-width="5" opacity="0.55">
    <line x1="78" y1="270" x2="414" y2="270"/>
    <line x1="78" y1="395" x2="414" y2="395"/>
    <line x1="78" y1="520" x2="414" y2="520"/>
    <line x1="78" y1="645" x2="414" y2="645"/>
  </g>
  <!-- Shattered dark window bays (front) -->
  <g fill="#1C2230" stroke="{ink}" stroke-width="6">
    <rect x="114" y="294" width="66" height="78" rx="3"/>
    <rect x="212" y="294" width="66" height="78" rx="3"/>
    <rect x="310" y="294" width="66" height="78" rx="3"/>
    <rect x="114" y="420" width="66" height="78" rx="3"/>
    <rect x="212" y="420" width="66" height="78" rx="3"/>
    <rect x="310" y="420" width="66" height="78" rx="3"/>
    <rect x="114" y="546" width="66" height="78" rx="3"/>
    <rect x="212" y="546" width="66" height="78" rx="3"/>
    <rect x="310" y="546" width="66" height="78" rx="3"/>
    <!-- Collapsed ground entrance -->
    <polygon points="184,752 184,668 308,668 308,752"/>
  </g>
  <!-- Shattered glass glint + cracks -->
  <path d="M 116 370 L 146 336 L 178 370 Z M 214 422 L 248 456 L 214 472 Z M 342 548 L 374 584 L 374 548 Z"
        fill="#7E97B4" opacity="0.48"/>
  <path d="M 178 242 L 208 286 L 194 334 M 368 486 L 392 536 L 376 588"
        fill="none" stroke="{ink}" stroke-width="5" stroke-linecap="round"/>
  <!-- Side windows -->
  <g fill="#151924" stroke="{ink}" stroke-width="5">
    <polygon points="444,316 534,344 534,406 444,380"/>
    <polygon points="444,440 534,466 534,528 444,504"/>
    <polygon points="444,564 534,588 534,648 444,626"/>
  </g>
  <!-- Rubble mound at base -->
  <polygon points="42,752 94,698 164,714 218,688 304,722 390,694 494,716 598,752"
           fill="#495365" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
</svg>
""")

    # 2. Collapsed Brutalist Building B (Wide bunker office ruin, 640x640)
    save_svg(os.path.join(RUIN_DIR, "building_b.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="640" viewBox="0 0 640 640">
  <defs>
    <linearGradient id="bldgB_front" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#96A4B8"/>
      <stop offset="60%" stop-color="#657387"/>
      <stop offset="100%" stop-color="#404A5B"/>
    </linearGradient>
  </defs>
  <path d="M 102 190 L 82 110 M 148 164 L 160 88 M 440 162 L 462 94 M 504 198 L 534 128"
        stroke="#2B2729" stroke-width="7" stroke-linecap="round"/>
  <!-- Side wing -->
  <polygon points="48,624 48,224 148,162 148,624" fill="#4B576A" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <!-- Main broad ruined concrete block -->
  <polygon points="148,624 148,162 248,194 342,144 468,170 578,226 578,624"
           fill="url(#bldgB_front)" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <!-- Collapsed diagonal roof slab resting across upper level -->
  <polygon points="244,196 474,168 456,214 232,238" fill="#7D8C9F" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
  <polyline points="152,166 248,198 342,148 468,174" fill="none" stroke="#F4B27A" stroke-width="5.5" opacity="0.72"/>
  <!-- Wide horizontal brutalist slit windows -->
  <g fill="#1B212F" stroke="{ink}" stroke-width="6">
    <rect x="184" y="268" width="152" height="64" rx="4"/>
    <rect x="378" y="268" width="152" height="64" rx="4"/>
    <rect x="184" y="384" width="152" height="64" rx="4"/>
    <rect x="378" y="384" width="152" height="64" rx="4"/>
    <rect x="268" y="502" width="186" height="122" rx="4"/>
  </g>
  <!-- Faded tactical yellow/orange sector band -->
  <rect x="154" y="468" width="420" height="18" fill="#C9873B" opacity="0.58"/>
  <!-- Rubble skirt -->
  <polygon points="28,624 114,578 214,598 352,576 492,598 612,624"
           fill="#485264" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
</svg>
""")

    # 3. Broken Highway Overpass Pillar (GFL2 landmark, 768x640)
    save_svg(os.path.join(RUIN_DIR, "overpass.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="768" height="640" viewBox="0 0 768 640">
  <defs>
    <linearGradient id="ovGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#9CA9BC"/>
      <stop offset="100%" stop-color="#535F72"/>
    </linearGradient>
  </defs>
  <!-- Massive central T-pillar -->
  <polygon points="294,624 316,246 452,246 474,624" fill="url(#ovGrad)" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <polygon points="452,246 502,262 518,624 474,624" fill="#3D4759" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <!-- Tilted snapped highway bridge deck -->
  <polygon points="64,194 652,102 712,188 594,242 132,272" fill="#7D8C9E" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <polygon points="64,194 652,102 642,74 52,166" fill="#A9B7C9" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
  <!-- Dangling snapped steel rebar bundles on broken deck ends -->
  <path d="M 62 184 L 18 228 M 74 206 L 26 266 M 664 134 L 742 166 M 684 162 L 750 218 M 632 198 L 716 254"
        stroke="#27242A" stroke-width="7" stroke-linecap="round"/>
  <!-- Warm dusk rim along top deck -->
  <line x1="56" y1="168" x2="640" y2="76" stroke="#F6B882" stroke-width="6" opacity="0.78"/>
  <!-- Rubble base -->
  <polygon points="224,624 282,572 396,590 506,574 568,624" fill="#465062" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
</svg>
""")

    # 4. Wrecked Post-Apocalyptic Sedan Car (512x320)
    save_svg(os.path.join(RUIN_DIR, "wrecked_car.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="320" viewBox="0 0 512 320">
  <defs>
    <linearGradient id="carBody" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#8B9EB2"/>
      <stop offset="55%" stop-color="#5C6E82"/>
      <stop offset="100%" stop-color="#3C4959"/>
    </linearGradient>
  </defs>
  <!-- Flat wheels -->
  <ellipse cx="144" cy="252" rx="44" ry="38" fill="#232730" stroke="{ink}" stroke-width="8"/>
  <ellipse cx="144" cy="252" rx="20" ry="17" fill="#697585" stroke="{ink}" stroke-width="5"/>
  <ellipse cx="378" cy="256" rx="42" ry="36" fill="#232730" stroke="{ink}" stroke-width="8"/>
  <ellipse cx="378" cy="256" rx="19" ry="16" fill="#697585" stroke="{ink}" stroke-width="5"/>
  <!-- Main battered sedan body -->
  <path d="M 38 228 L 54 166 L 132 146 L 182 88 L 328 88 L 388 144 L 466 164 L 478 232 L 422 248 L 92 248 Z"
        fill="url(#carBody)" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <!-- Subtle rust patches -->
  <path d="M 68 184 Q 112 172 130 202 Q 96 220 62 206 Z" fill="#8C533B" opacity="0.58"/>
  <path d="M 392 176 Q 434 170 456 196 Q 426 216 388 202 Z" fill="#8C533B" opacity="0.52"/>
  <!-- Shattered windows -->
  <polygon points="156,144 192,102 256,102 256,146" fill="#202836" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <polygon points="270,102 322,102 364,144 270,146" fill="#202836" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <!-- Windshield spiderweb cracks -->
  <path d="M 284 114 L 308 134 M 298 106 L 308 134 L 336 126" stroke="#A6BDD4" stroke-width="3.5" opacity="0.8"/>
  <!-- Door seam, bumpers & warm roof highlight -->
  <path d="M 184 152 L 184 240 M 266 152 L 266 240" stroke="{ink}" stroke-width="5.5"/>
  <rect x="26" y="210" width="44" height="22" rx="6" fill="#323946" stroke="{ink}" stroke-width="6"/>
  <rect x="444" y="212" width="44" height="22" rx="6" fill="#323946" stroke="{ink}" stroke-width="6"/>
  <path d="M 186 92 L 324 92" stroke="#F4C294" stroke-width="5" opacity="0.75"/>
</svg>
""")

    # 5. Tactical Concrete Barrier + Sandbags Cover (512x300)
    save_svg(os.path.join(RUIN_DIR, "tactical_cover.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="300" viewBox="0 0 512 300">
  <defs>
    <linearGradient id="concGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#A8B4C4"/>
      <stop offset="100%" stop-color="#687486"/>
    </linearGradient>
    <linearGradient id="bagGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#C8B692"/>
      <stop offset="100%" stop-color="#8B7A5C"/>
    </linearGradient>
  </defs>
  <!-- Heavy concrete Jersey barrier -->
  <polygon points="36,272 56,118 358,118 378,272" fill="url(#concGrad)" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <polygon points="56,118 82,92 384,92 358,118" fill="#C4CEDC" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
  <polygon points="358,118 384,92 402,248 378,272" fill="#525D6E" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
  <!-- Hazard yellow/black chevron band -->
  <polygon points="62,150 352,150 356,182 58,182" fill="#E2A93B" stroke="{ink}" stroke-width="5"/>
  <path d="M 92 150 L 72 182 M 148 150 L 128 182 M 204 150 L 184 182 M 260 150 L 240 182 M 316 150 L 296 182"
        stroke="{ink}" stroke-width="14"/>
  <!-- Cracks -->
  <path d="M 190 118 L 204 148 M 292 204 L 310 242 L 298 268" stroke="{ink}" stroke-width="5" fill="none"/>
  <!-- Stacked tactical sandbags on right flank -->
  <ellipse cx="412" cy="248" rx="68" ry="28" fill="url(#bagGrad)" stroke="{ink}" stroke-width="7"/>
  <ellipse cx="322" cy="252" rx="64" ry="26" fill="url(#bagGrad)" stroke="{ink}" stroke-width="7"/>
  <ellipse cx="376" cy="212" rx="66" ry="27" fill="url(#bagGrad)" stroke="{ink}" stroke-width="7"/>
  <ellipse cx="424" cy="180" rx="54" ry="24" fill="url(#bagGrad)" stroke="{ink}" stroke-width="7"/>
</svg>
""")

    # 6. Encrypted Tactical Supply Crate (384x340)
    save_svg(os.path.join(RUIN_DIR, "supply_crate.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="384" height="340" viewBox="0 0 384 340">
  <defs>
    <linearGradient id="crateTop" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#6B7968"/>
      <stop offset="100%" stop-color="#4A5648"/>
    </linearGradient>
    <linearGradient id="crateFront" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#536052"/>
      <stop offset="100%" stop-color="#353E35"/>
    </linearGradient>
  </defs>
  <!-- Isometric heavy military case -->
  <polygon points="48,142 192,76 336,142 192,208" fill="url(#crateTop)" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <polygon points="48,142 192,208 192,312 48,246" fill="url(#crateFront)" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <polygon points="336,142 192,208 192,312 336,246" fill="#2E362F" stroke="{ink}" stroke-width="8" stroke-linejoin="round"/>
  <!-- Reinforced steel corner bumpers -->
  <polygon points="48,142 192,208 192,232 48,166" fill="#3B424D" stroke="{ink}" stroke-width="6"/>
  <polygon points="336,142 192,208 192,232 336,166" fill="#2C323B" stroke="{ink}" stroke-width="6"/>
  <!-- Glowing Cyan Encryption Lock Panel -->
  <polygon points="98,204 146,226 146,262 98,240" fill="#1D2632" stroke="{ink}" stroke-width="5"/>
  <polygon points="106,214 138,229 138,248 106,233" fill="#46E8FF"/>
  <!-- Orange tactical stencil mark on lid -->
  <polygon points="154,126 192,108 232,126 192,144" fill="#F29F3D" stroke="{ink}" stroke-width="4.5"/>
</svg>
""")

    # 7. Bent Post-Apocalyptic Streetlight (320x640)
    save_svg(os.path.join(RUIN_DIR, "streetlight.svg"), f"""
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="640" viewBox="0 0 320 640">
  <!-- Concrete pole footing -->
  <polygon points="94,626 108,554 164,554 178,626" fill="#697586" stroke="{ink}" stroke-width="7" stroke-linejoin="round"/>
  <!-- Slightly bent rusted steel lamp post -->
  <path d="M 136 558 L 146 286 L 166 92 C 170 64, 202 52, 248 64"
        fill="none" stroke="{ink}" stroke-width="26" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M 136 558 L 146 286 L 166 92 C 170 64, 202 52, 248 64"
        fill="none" stroke="#636E7E" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>
  <!-- Lamp fixture hood -->
  <path d="M 224 54 L 292 70 L 284 94 L 218 78 Z" fill="#3D4554" stroke="{ink}" stroke-width="6" stroke-linejoin="round"/>
  <!-- Warm glowing sodium lamp bulb -->
  <ellipse cx="252" cy="88" rx="22" ry="11" transform="rotate(14 252 88)" fill="#FFE08C" stroke="{ink}" stroke-width="4"/>
</svg>
""")


def main():
    characters = [
        {
            "id": "reina_ar",
            "hair_style": "ponytail",
            "hair_base": "#E8EEF7",
            "hair_dark": "#9EAEC6",
            "hair_hi": "#FFFFFF",
            "eye_top": "#1A5296",
            "eye_pupil": "#2B88E0",
            "eye_bot": "#82EEFF",
            "jacket_main": "#F4F7FC",
            "jacket_shadow": "#C7D2E3",
            "accent": "#38D6FF",
            "accent_dark": "#1C8FB8",
            "skirt_main": "#2A3D66",
            "skirt_shadow": "#1B2846",
            "sock_col": "#242A3A",
            "boot_col": "#2A2F3D",
            "halo_style": "ring_star",
            "halo_col": "#48E4FF",
            "halo_glow": "#80F2FF",
        },
        {
            "id": "chisa_smg",
            "hair_style": "bob_goggles",
            "hair_base": "#2A3A5C",
            "hair_dark": "#18233A",
            "hair_hi": "#546D9E",
            "eye_top": "#964E0C",
            "eye_pupil": "#E28B18",
            "eye_bot": "#FFE066",
            "jacket_main": "#637265",
            "jacket_shadow": "#434F46",
            "accent": "#F5A623",
            "accent_dark": "#B86E10",
            "skirt_main": "#353C4A",
            "skirt_shadow": "#232833",
            "sock_col": "#3B404E",
            "boot_col": "#5A3D2B",
            "halo_style": "gear",
            "halo_col": "#FFB830",
            "halo_glow": "#FFE082",
        },
        {
            "id": "lily_sg",
            "hair_style": "twintails",
            "hair_base": "#F4C458",
            "hair_dark": "#C68C2E",
            "hair_hi": "#FFF0A6",
            "eye_top": "#8C1630",
            "eye_pupil": "#DF2A4C",
            "eye_bot": "#FF8AA0",
            "jacket_main": "#3A3642",
            "jacket_shadow": "#24212B",
            "accent": "#F03852",
            "accent_dark": "#A61D34",
            "skirt_main": "#B8283E",
            "skirt_shadow": "#7D1A2B",
            "sock_col": "#F2F4F8",
            "boot_col": "#2A242D",
            "halo_style": "crosshair",
            "halo_col": "#FF4262",
            "halo_glow": "#FF8CA0",
        },
    ]

    for cfg in characters:
        cid = cfg["id"]
        save_svg(os.path.join(CHAR_DIR, f"{cid}_body.svg"), build_chibi_character_svg(cfg))
        save_svg(
            os.path.join(CHAR_DIR, f"{cid}_halo.svg"),
            build_halo_svg(cfg["halo_style"], cfg["halo_col"], cfg["halo_glow"]),
        )
    build_weapons()
    build_ruins_sprites()
    print("[2.5D Sprites] Generated 3 Blue Archive chibi sprites + halos + 3 weapons + 7 GFL2 ruins sprites.")


if __name__ == "__main__":
    main()
