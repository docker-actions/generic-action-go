ARG ROOTFS=/build/rootfs

FROM golang:1.19-alpine3.17 as build

ARG IMAGE_NAME
ARG ROOTFS
ARG GO_INSTALL=""
ARG REQUIRED_PACKAGES=""

RUN : "${IMAGE_NAME:?Build argument needs to be set and non-empty.}"
RUN : "${ROOTFS:?Build argument needs to be set and non-empty.}"

# Install pre-requisites
RUN apk update \
      && apk add --no-cache bash git

# Build pre-requisites
RUN bash -c 'mkdir -p ${ROOTFS}/{bin,sbin,usr/share,usr/bin,usr/sbin,usr/lib,/usr/local/bin,etc,container_user_home}'

# Install packages
RUN for pkg in $GO_INSTALL; do \
       go install $pkg; \
     done

RUN cp /go/bin/* ${ROOTFS}/usr/bin

# Initialize ROOTFS if REQUIRED_PACKAGES was set
RUN test "x${REQUIRED_PACKAGES}" != "x" && apk add --root ${ROOTFS} --update-cache --initdb \
      && mkdir -p ${ROOTFS}/etc/apk \
      && cp -r /etc/apk/repositories ${ROOTFS}/etc/apk/repositories \
      && cp -r /etc/apk/keys ${ROOTFS}/etc/apk/keys \
      && apk --no-cache add -p ${ROOTFS} ${REQUIRED_PACKAGES} \
      || echo REQUIRED_PACKAGES not set

# Move /sbin out of the way
RUN mv ${ROOTFS}/sbin ${ROOTFS}/sbin.orig \
      && mkdir -p ${ROOTFS}/sbin \
      && for b in ${ROOTFS}/sbin.orig/*; do \
           echo 'cmd=$(basename ${BASH_SOURCE[0]}); exec /sbin.orig/$cmd "$@"' > ${ROOTFS}/sbin/$(basename $b); \
           chmod +x ${ROOTFS}/sbin/$(basename $b); \
         done

COPY ${IMAGE_NAME}.entrypoint.sh ${ROOTFS}/usr/local/bin/entrypoint.sh
RUN chmod +x ${ROOTFS}/usr/local/bin/entrypoint.sh

FROM actions/bash:5.2.12-1-alpine3.17
LABEL maintainer = "ilja+docker@bobkevic.com"

ARG ROOTFS

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY --from=build ${ROOTFS} /

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
