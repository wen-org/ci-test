ARG VER

FROM python:${VER}-slim

ENV DGLBACKEND=pytorch

RUN pip install --quiet --no-cache-dir torch==1.12.0 --extra-index-url https://download.pytorch.org/whl/cpu && \
    pip install --quiet --no-cache-dir torch-scatter==2.0.9 torch-sparse==0.6.14 torch-cluster==1.6.0 torch-spline-conv==1.2.1 torch-geometric==2.0.4 -f https://data.pyg.org/whl/torch-1.12.0+cpu.html && \
    pip install --quiet --no-cache-dir dgl -f https://data.dgl.ai/wheels/repo.html && \
    pip install --quiet --no-cache-dir \
        class-resolver==0.3.9 \
        kafka-python==2.0.2 \
        requests

RUN mkdir /opt/mlwb
COPY --chown=root:root ./run.sh /opt/mlwb/run.sh
RUN chmod +x /opt/mlwb/run.sh

ENTRYPOINT ["/opt/mlwb/run.sh"]