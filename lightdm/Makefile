.PHONY: install

LIGHTDM_DIR = $(DESTDIR)/etc/lightdm
LIGHTDM_DROPIN = $(LIGHTDM_DIR)/lightdm.conf.d/50-dwm-titus.conf
PIXMAPS_DIR = $(DESTDIR)/usr/share/pixmaps

# lightdm.conf stays owned by the administrator. The session settings ship as
# a drop-in, which LightDM reads before lightdm.conf, so local values win.
install:
	install -Dm644 50-dwm-titus.conf                 $(LIGHTDM_DROPIN)
	install -Dm644 slick-greeter.conf                $(LIGHTDM_DIR)/slick-greeter.conf
	install -Dm644 wallpaper.jpg                     $(PIXMAPS_DIR)/dwm-titus.jpg
	install -Dm644 ../dwm-titus.png                  $(PIXMAPS_DIR)/dwm-titus-logo.png
