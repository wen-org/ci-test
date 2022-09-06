ARG VER

FROM docker.tigergraph.com/tigergraph:${VER}

USER tigergraph

# ---- Ingest Data ----
COPY --chown=tigergraph:tigergraph ./Data/Cora/ /home/tigergraph/Data/Cora/
COPY --chown=tigergraph:tigergraph ./Data/imdb/ /home/tigergraph/Data/imdb/
COPY --chown=tigergraph:tigergraph ./Data/fake-hetero/ /home/tigergraph/Data/hetero/
COPY --chown=tigergraph:tigergraph ./Data/Social/ /home/tigergraph/Data/Social/
RUN /home/tigergraph/tigergraph/app/cmd/gadmin start all && \
    cd /home/tigergraph/Data/Cora/ && \
    /home/tigergraph/tigergraph/app/cmd/gsql ingest.gsql && \
    cd /home/tigergraph/Data/imdb/ && \
    /home/tigergraph/tigergraph/app/cmd/gsql ingest.gsql && \
    cd /home/tigergraph/Data/hetero/ && \
    /home/tigergraph/tigergraph/app/cmd/gsql ingest.gsql && \
    cd /home/tigergraph/Data/Social/ && \
    /home/tigergraph/tigergraph/app/cmd/gsql ingest.gsql

COPY --chown=tigergraph:tigergraph ./start.sh /home/tigergraph/start.sh
RUN chmod +x /home/tigergraph/start.sh

ENTRYPOINT ["/home/tigergraph/start.sh"]
