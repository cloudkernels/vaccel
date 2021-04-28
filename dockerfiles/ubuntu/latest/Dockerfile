FROM ubuntu:latest as rootfs-builder

ENV DEBIAN_FRONTEND=noninteractive

ARG KERNEL_VERSION

RUN apt-get update && apt-get install -y \
      init \
      kmod \
      openssh-server \
      udev && \
    apt-get clean

# virtio module setup
RUN mkdir -p /lib/modules/${KERNEL_VERSION}
COPY share/virtio_accel.ko /lib/modules/${KERNEL_VERSION}
RUN touch /lib/modules/${KERNEL_VERSION}/modules.order
RUN touch /lib/modules/${KERNEL_VERSION}/modules.builtin
RUN depmod 4.20.0
RUN echo "virtio_accel" >> /etc/modules

# Copy libvaccel inside the image
RUN mkdir -p /opt/vaccel/bin
COPY bin/classify /opt/vaccel/bin
COPY lib /opt/vaccel/lib
COPY include /opt/vaccel/include
COPY imagenet/images share
RUN echo "/opt/vaccel/lib" >> /etc/ld.so.conf.d/vaccel.conf
RUN echo "/sbin/ldconfig" >> /root/.bashrc
RUN echo "export VACCEL_BACKENDS=/opt/vaccel/lib/libvaccel-virtio.so" >> /root/.bashrc

# Enable ssh server
RUN systemctl enable ssh
#COPY fc_test.pub id_rsa.pub
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
RUN echo "PermitEmptyPasswords yes" >> /etc/ssh/sshd_config
#RUN mkdir /root/.ssh/ && \
#    cat id_rsa.pub >> /root/.ssh/authorized_keys && \
#    chmod 0700 /root/.ssh && \
#    chmod 0600 /root/.ssh/authorized_keys && \
#    chown -R root:root /root/.ssh

# Disable root password
RUN sed s/root\:x\:/root\:\:/ -i /etc/passwd
RUN sed s/root\:\*\:/root\:\:/ -i /etc/shadow

# Set hostname
RUN echo "vaccel-guest.nubificus.co.uk" > /etc/hostname

# Write out everything
FROM scratch as artifact
COPY --from=rootfs-builder / /rootfs
