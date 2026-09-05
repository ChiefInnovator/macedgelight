from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageCms
import json
P=Path(__file__).resolve().parent
W,H=1080,1350
BG='#111820'; WHITE='#F7F3EA'; MUTED='#BFC9CF'; GOLD='#FFBD62'; BLUE='#A9DCFF'
def font(n,bold=False):return ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial'+(' Bold' if bold else '')+'.ttf',n)
slides=json.loads((P/'slides.json').read_text())
profile=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
for i,s in enumerate(slides,1):
 im=Image.new('RGB',(W,H),BG); d=ImageDraw.Draw(im)
 def txt(x,y,t,n=40,c=WHITE,b=False,spacing=12):
  box=d.multiline_textbbox((x,y),t,font=font(n,b),spacing=spacing)
  assert box[2]<=1010 and box[3]<=1280,(i,t,box)
  d.multiline_text((x,y),t,font=font(n,b),fill=c,spacing=spacing)
 def photo(y):
  ph=Image.open(P/'assets/product-photo.jpg').convert('RGB'); ph=ph.resize((920,483),Image.Resampling.LANCZOS);im.paste(ph,(80,y))
 def card(x,y,w,h,fill):d.rounded_rectangle((x,y,x+w,y+h),radius=22,fill=fill)
 d.rectangle((0,0,W,12),fill=GOLD)
 txt(80,86,'INVENTING FIRE WITH AI',25,GOLD,True)
 txt(80,172,s['kicker'],28,BLUE,True)
 if s['kind']=='cover':
  txt(80,235,s['title'],72,b=True);txt(80,526,s['body'],45,GOLD,True);txt(80,583,'New: queued recovery for quick boost toggles.',29,c=MUTED);photo(632);txt(80,1130,s['note'],36)
 elif s['kind']=='photo':
  txt(80,245,s['title'],80,b=True);txt(80,468,s['body'],40,c=MUTED);photo(625);txt(80,1140,s['note'],35)
 elif s['kind']=='boost':
  txt(80,245,s['title'],76,b=True);txt(80,468,s['body'],40,c=MUTED)
  card(80,625,920,390,'#1C3040');txt(120,665,'EDR',145,BLUE,True);txt(120,850,'Compatible displays',44,b=True);txt(120,921,'Independent control',36,c=MUTED)
  txt(80,1060,s['note'],35);txt(80,1130,'Available brightness depends on your display\nand macOS.',34,c=MUTED)
 elif s['kind']=='quote':
  txt(80,285,s['title'],77,b=True,spacing=23);d.rectangle((80,760,180,768),fill=GOLD);txt(80,815,s['body'],40,c=GOLD,spacing=18);txt(80,1050,'A personal experience with\nDisplay Brightness Boost.',38,c=MUTED)
 elif s['kind']=='recovery':
  txt(80,245,s['title'],77,b=True);txt(80,470,s['body'],39,c=MUTED)
  for j,(a,b) in enumerate([('1','Off'),('2','Waiting'),('3','Auto retry')]):
   x=80+j*314;card(x,670,292,237,'#1C3040');txt(x+25,695,a,56,GOLD,True);txt(x+25,812,b,37,b=True)
  txt(80,960,s['note'],36);txt(80,1060,'A recovery workaround, not a guarantee\nof physical brightness.',36,c=MUTED)
 elif s['kind']=='cta':
  txt(80,245,s['title'],85,b=True);txt(80,490,s['body'],39,c=MUTED)
  card(80,682,920,147,GOLD);txt(118,726,'Download MacEdgeLight 3.0.1',49,BG,True)
  txt(80,900,'chiefinnovator.github.io/macedgelight/',42,BLUE,True);txt(80,1000,s['note'],36)
  txt(80,1072,'Apple-notarized download',34,c=MUTED)
 d.line((80,1210,1000,1210),fill='#40505C',width=2)
 txt(80,1240,'MacEdgeLight 3.0.1',26,c=MUTED);txt(900,1240,f'{i:02d} / 06',24,c=MUTED)
 im.save(P/f'slide-{i:02d}.jpg',quality=95,subsampling=0,icc_profile=profile)
# The full verified brand lockup is supplied on the preview and in editable assets.
preview=Image.new('RGB',(1140,1080),'#EEECE6');pd=ImageDraw.Draw(preview)
logo=Image.open(P/'assets/brand.png').convert('RGBA');logo.thumbnail((105,110));preview.paste(logo,(22,12),logo)
pd.text((152,25),'INVENTING FIRE WITH AI',font=font(29,True),fill=BG)
pd.text((152,70),'MacEdgeLight 3.0.1 / six-slide release carousel',font=font(23),fill=BG)
for j in range(6):
 thumb=Image.open(P/f'slide-{j+1:02d}.jpg');thumb.thumbnail((352,440));preview.paste(thumb,(24+(j%3)*372,148+(j//3)*458))
preview.save(P/'preview.jpg',quality=95,icc_profile=profile)
print(P)
