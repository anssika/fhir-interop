FROM intersystems/irishealth-community:2026.2

# normal (not summer) time in Finland
ENV TZ=EET-2

# Copy build phase files
COPY build/ /opt/fhir-interop/build/

# Copy source code
COPY src/ /opt/fhir-interop/src/

# Iris databases etc. to create when IRIS starts
ENV ISC_CPF_MERGE_FILE=/opt/fhir-interop/build/build.cpf

WORKDIR /opt/fhir-interop

# Run build phase
# Start IRIS, merge CPF, run build script, then stop
RUN iris start IRIS && \
	./build/build.sh && \
    iris stop IRIS quietly