Compiler=g++

LDFLAGS=	-lobjc -O2 -g0 \
				-framework Foundation \
				-framework UIKit \
				-framework CoreFoundation \
				-framework CoreGraphics \
				-framework GraphicsServices \
				-multiply_defined suppress \
				-L/usr/lib \
				-F/System/Library/Frameworks \
				-F/System/Library/PrivateFrameworks \
				-dynamiclib \
				-init _WeatherIconInitialize \
				-Wall \
				-Werror \
				-lsubstrate \
				-lobjc \
				-ObjC++ \
				-fobjc-exceptions \
				-march=armv6 \
				-mcpu=arm1176jzf-s \
				-fobjc-call-cxx-cdtors

CFLAGS= -O2 -dynamiclib \
  -fsigned-char -g0 -fobjc-exceptions \
  -Wall -Wundeclared-selector -Wreturn-type \
  -Wredundant-decls \
  -Wchar-subscripts \
  -Winline -Wswitch -Wshadow \
  -I/var/include \
  -I/var/include/gcc/darwin/4.0 \
  -D_CTYPE_H_ \
  -D_BSD_ARM_SETJMP_H \
  -D_UNISTD_H_

Objects=WeatherIconModel.o WeatherIcon.o
Target=WeatherIcon.dylib

all:	$(Target)

install: 	$(Target)
		chmod 755 $(Target)
		rm -f /Library/MobileSubstrate/DynamicLibraries/$(Target)
		cp $(Target) /Library/MobileSubstrate/DynamicLibraries/
		cp *.plist /Library/MobileSubstrate/DynamicLibraries/
		restart

$(Target):	$(Objects)
		$(Compiler) $(LDFLAGS) -o $@ $^
		ldid -S $(Target)

%.o:	%.mm
		$(Compiler) -c $(CFLAGS) $< -o $@

clean:
		rm -f *.o $(Target)
		rm -rf package

package:	$(Target)
	mkdir -p package/weathericon/DEBIAN
	mkdir -p package/weathericon/Library/MobileSubstrate/DynamicLibraries
	mkdir -p package/weathericon/System/Library/CoreServices/SpringBoard.app
	cp -a $(Target) package/weathericon/Library/MobileSubstrate/DynamicLibraries
	cp -a *.plist package/weathericon/Library/MobileSubstrate/DynamicLibraries
	cp -a *.png package/weathericon/System/Library/CoreServices/SpringBoard.app
	cp -a control package/weathericon/DEBIAN
	find package/weathericon -name .svn -print0 | xargs -0 rm -rf
	dpkg-deb -b package/weathericon weathericon_$(shell grep ^Version: control | cut -d ' ' -f 2)_iphoneos-arm.deb
