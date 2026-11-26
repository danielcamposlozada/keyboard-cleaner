PROG = keylock
APP  = Keyboard Cleaner.app

INSTALL ?= install
RM      ?= rm -f
MKDIR   ?= install -d

PREFIX ?= /usr/local
BINDIR = ${DESTDIR}${PREFIX}/bin
APPDIR ?= /Applications

OBJDIR = .build
RELDIR = ${OBJDIR}/release

all: app

# Menu bar app -> build/Keyboard Cleaner.app
app:
	./scripts/bundle.sh

install-app: app
	rm -rf "${APPDIR}/${APP}"
	ditto "build/${APP}" "${APPDIR}/${APP}"

# Command-line tool
build:
	swift build -c release --product ${PROG}

debug:
	swift build -c debug

install: bootstrap build
	${INSTALL} ${RELDIR}/${PROG} ${BINDIR}/${PROG}

bootstrap:
	${MKDIR} ${BINDIR}

uninstall:
	${RM} ${BINDIR}/${PROG}
	rm -rf "${APPDIR}/${APP}"

clean:
	${RM} -r ${OBJDIR} build

.PHONY: all app install-app bootstrap build debug install uninstall clean
