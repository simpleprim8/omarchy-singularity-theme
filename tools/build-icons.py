#!/usr/bin/env python3
"""Create the original Singularity vector icon family from shared geometry."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'system-ui/icons/Singularity'
COLORS={'green':'#59d98b','violet':'#b4a0d2','blue':'#86b3d1','orange':'#dca276','red':'#ec8181'}
GLYPHS={
'folder':'<path d="M25 40h14m-10-5 6 10m0-10-6 10"/>',
'home':'<path d="m24 38 8-7 8 7m-13-2v11h10V36m-7 11v-7h4v7"/>',
'documents':'<path d="M27 30h8l4 4v14H27Zm8 0v5h4m-9 4h6m-6 4h6"/>',
'download':'<path d="M32 30v13m-6-6 6 6 6-6m-13 9h14"/>',
'music':'<path d="M30 43V32l10-2v11m-10-5 10-2"/><ellipse cx="27" cy="44" rx="3" ry="2"/><ellipse cx="37" cy="42" rx="3" ry="2"/>',
'pictures':'<rect x="23" y="31" width="18" height="15" rx="2"/><path d="m24 44 6-6 4 4 3-3 4 5"/><circle cx="36" cy="35" r="1.3"/>',
'videos':'<rect x="23" y="31" width="18" height="15" rx="2"/><path d="m30 35 6 4-6 4Z"/>',
'desktop':'<rect x="23" y="30" width="18" height="13" rx="1.5"/><path d="M32 43v5m-5 0h10"/>',
'public':'<circle cx="32" cy="38" r="8"/><ellipse cx="32" cy="38" rx="3" ry="8"/><path d="M24 38h16m-14-5h12m-12 10h12"/>',
'projects':'<path d="m27 33-5 6 5 6m10-12 5 6-5 6m-7 2 4-16"/>',
'downloads':'',
'templates':'<path d="M25 31h14v16H25Zm4 0v16m-4-11h14m-7 4h4m-4 4h4"/>',
'archive':'<path d="M25 31h14v16H25Zm5 0v16m-2-13h4m-4 5h4m-4 5h4"/>',
'file':'<path d="M26 30h9l4 4v14H26Zm9 0v5h4m-10 4h7m-7 4h7"/>',
'pdf':'<path d="M25 44V33h5a3 3 0 0 1 0 6h-5m10 5V33h4m-4 5h3"/>',
'code':'<path d="m27 33-5 6 5 6m10-12 5 6-5 6m-7 2 4-16"/>',
'trash':'<path d="M25 34h14m-11-4h8m-10 4 1 14h10l1-14m-8 4v7m4-7v7"/>',
'drive':'<path d="M23 34h18v13H23Zm2-4h14l2 4H23Zm2 12h5"/><circle cx="37" cy="42" r="1"/>',
'network':'<circle cx="32" cy="32" r="4"/><circle cx="24" cy="45" r="3"/><circle cx="40" cy="45" r="3"/><path d="M32 36v4m0 0h-8v2m8-2h8v2"/>',
'favorite':'<path d="m32 30 2.6 5.3 5.9.9-4.3 4.1 1 5.9-5.2-2.8-5.2 2.8 1-5.9-4.3-4.1 5.9-.9Z"/>',
'lock':'<rect x="25" y="37" width="14" height="11" rx="2"/><path d="M28 37v-4a4 4 0 0 1 8 0v4m-4 4v3"/>',
}

def svg(kind, accent='blue', folder=True):
 glyph=GLYPHS[kind];color=COLORS[accent]
 defs='<defs><linearGradient id="face" x2="0" y2="1"><stop stop-color="#15372c"/><stop offset="1" stop-color="#081710"/></linearGradient></defs>'
 if folder:
  shape='<path d="M7 21v-6h17l6 6h25v31H7Z" fill="#142b25" stroke="#628d85" stroke-width="1.2"/><path d="M9 15h15l6 6h12" fill="none" stroke="#b4a0d2" stroke-width="1.6"/><path d="M6 23h22l4 3h26v24l-5 5H11l-5-5Z" fill="url(#face)" stroke="#59d98b" stroke-width="1.3"/><path d="M10 28v19l4 4h36" fill="none" stroke="#59d98b" stroke-width=".8" opacity=".5"/>'
 else:
  shape='<path d="M17 8h22l10 10v37H17Z" fill="url(#face)" stroke="#59d98b" stroke-width="1.3"/><path d="M39 8v12h10" fill="#263b3d" stroke="#b4a0d2" stroke-width="1.2"/><path d="M21 13v37h23" fill="none" stroke="#59d98b" stroke-width=".8" opacity=".4"/>'
 grid='<path d="M9 50q23-10 46 0M13 54q20-14 39 0m-31 0 8-14m15 14L35 40" fill="none" stroke="#59d98b" stroke-width=".65" opacity=".2"/>' if folder else ''
 return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{defs}{shape}{grid}<g fill="none" stroke="{color}" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round">{glyph}</g></svg>\n'

def write(context,names,kind,accent='blue',folder=True):
 for name in names.split():
  path=ROOT/'scalable'/context/(name+'.svg');path.parent.mkdir(parents=True,exist_ok=True);path.write_text(svg(kind,accent,folder))

write('places','folder inode-directory folder-open','folder','green')
for kind,names in {
 'home':'user-home folder-home', 'documents':'folder-documents', 'download':'folder-download folder-downloads',
 'music':'folder-music', 'pictures':'folder-pictures folder-photos', 'videos':'folder-videos',
 'desktop':'user-desktop folder-desktop', 'public':'folder-publicshare folder-remote folder-network',
 'projects':'folder-development folder-code folder-projects','templates':'folder-templates',
 'favorite':'folder-favorites user-bookmarks', 'trash':'user-trash user-trash-full',
 'network':'network-workgroup network-server', 'lock':'folder-locked folder-encrypted',
}.items():write('places',names,kind,'violet' if kind in ('home','desktop','templates') else 'orange' if kind in ('favorite','download') else 'blue')
for kind,names,accent in (
 ('file','text-x-generic text-plain text-x-markdown application-rtf','blue'),
 ('code','text-x-script text-x-python text-x-c text-x-c++ text-x-java text-html application-json application-xml text-xml application-x-shellscript','violet'),
 ('pdf','application-pdf','red'),('pictures','image-x-generic image-png image-jpeg image-svg+xml','blue'),
 ('music','audio-x-generic audio-mpeg audio-x-wav audio-flac','violet'),('videos','video-x-generic video-mp4','blue'),
 ('archive','package-x-generic application-zip application-x-7z-compressed application-x-rar application-x-tar application-gzip','orange'),
 ('projects','application-x-executable application-x-sharedlib application-octet-stream','green')):
 write('mimetypes',names,kind,accent,False)
write('devices','drive-harddisk drive-removable-media drive-optical media-flash media-removable','drive','blue',False)
# Monochrome place icons keep sidebar/toolbar coloring under GTK's control.
for kind,names in {'home':'user-home folder-home','documents':'folder-documents','download':'folder-download folder-downloads','music':'folder-music','pictures':'folder-pictures','videos':'folder-videos','desktop':'user-desktop folder-desktop','public':'folder-publicshare','templates':'folder-templates','folder':'folder folder-open','trash':'user-trash user-trash-full','network':'network-workgroup network-server','favorite':'user-bookmarks folder-favorites'}.items():
 for name in names.split():
  path=ROOT/'symbolic/places'/(name+'-symbolic.svg');path.parent.mkdir(parents=True,exist_ok=True)
  path.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="20 27 24 24"><g fill="none" stroke="#2e3436" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'+GLYPHS[kind]+'</g></svg>\n')
contexts=('scalable/places','scalable/mimetypes','scalable/devices','symbolic/places')
index='[Icon Theme]\nName=Singularity\nComment=Original spacetime-inspired icons for the Singularity desktop\nInherits=Adwaita,Yaru-prussiangreen-dark,hicolor\nExample=folder\nDirectories='+','.join(contexts)+'\n'
for directory in contexts:
 index+='\n['+directory+']\nSize='+('16' if directory.startswith('symbolic') else '64')+'\nMinSize=16\nMaxSize=256\nType=Scalable\nContext='+directory.split('/')[1].title()+'\n'
(ROOT/'index.theme').write_text(index)
print('Built',len(list(ROOT.rglob('*.svg'))),'original SVG icons')
