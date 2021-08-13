FROM ubuntu:latest as rootfs-builder

ENV DEBIAN_FRONTEND=noninteractive

ARG KERNEL_VERSION

RUN apt-get update && apt-get install -y \
      init \
      kmod \
      openssh-server \
      udev \
      gdb \
      valgrind \
      rsync \
      iproute2 && \
    apt-get clean

# Prepare immutable vAccel properties
RUN mkdir -p /opt/vaccel
RUN echo "/opt/vaccel/lib" >> /etc/ld.so.conf.d/vaccel.conf
RUN echo "/sbin/ldconfig" >> /root/.bashrc
RUN echo "export VACCEL_BACKENDS=/opt/vaccel/lib/libvaccel-vsock.so" >> /root/.bashrc
RUN echo "export VACCEL_DEBUG_LEVEL=4" >> /root/.bashrc

# Enable ssh server
RUN systemctl enable ssh
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
RUN echo "PermitEmptyPasswords yes" >> /etc/ssh/sshd_config

# Disable root password
RUN sed s/root\:x\:/root\:\:/ -i /etc/passwd
RUN sed s/root\:\*\:/root\:\:/ -i /etc/shadow

# Set hostname
RUN echo "vaccel-guest.nubificus.co.uk" > /etc/hostname

# Write out everything
FROM scratch as artifact
COPY --from=rootfs-builder / /rootfs
