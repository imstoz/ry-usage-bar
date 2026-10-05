from pathlib import Path
app = str(Path(defines['app']).resolve())
files = [app]
symlinks = {'Applications': '/Applications'}
format = 'UDZO'
filesystem = 'HFS+'
background = str(Path(defines['background']).resolve())
window_rect = ((200, 200), (640, 400))
default_view = 'icon-view'
show_toolbar = False
show_status_bar = False
show_sidebar = False
show_pathbar = False
icon_size = 96
text_size = 13
icon_locations = {'ry Usage Bar.app': (170, 200), 'Applications': (470, 200)}
hide_extensions = ['ry Usage Bar.app']
