#! /bin/bash

####################################################
####################################################
############ ADD NEW FUZERS HERE! ##################
####################################################
####################################################

# Follow the naming scheme. There will be breakage if not.
# Start the name of the function with "test_with_"
# and then use the name of the /container/ (not the service
# in case they differ).

# In the function body follow the examples.
# Use `docker exec <fuzzer-container-name> /bin/sh -c "command to fuzz here"
# You get two args here
# $1 = name of the target container
# $2 = port of the target container

# There are quite a few env-vars that you can use. The most useful are
# $FUZZER_SCHEMA_DIR = the path where schemas have been mounted to
# $CONTAINER_OUTPUTS = tha path for outputs that have been muonted

# Regarding the output-paths. It is important to use $1 to separate
# the outputs. In other words, for ALL output-path use
# `${CONTAINER_OUTPUTS}/$1`. Otherwise the fuzzer would overwrite
# these when it start to fuzz next target.

test_with_fuzzer-cats(){
    docker exec fuzzer-cats /bin/sh -c "./cats \
    	   --contract=${FUZZER_SCHEMA_DIR}/$1.json \
	   --server=http://$1:$2 \
           --output=${CONTAINER_OUTPUTS}/$1"
}

test_with_fuzzer-restler(){
    docker exec fuzzer-restler /bin/sh -c "mkdir ${CONTAINER_OUTPUTS}/$1 && \
    	   cd ${CONTAINER_OUTPUTS}/$1 && \
    	   /RESTler/restler/Restler generate_config \
    	   		    --specs ${FUZZER_SCHEMA_DIR}/$1.json && \
    	   /RESTler/restler/Restler compile ${CONTAINER_OUTPUTS}/$1/restlerConfig/config.json && \
           /RESTler/restler/Restler fuzz \
    			     --grammar_file ${CONTAINER_OUTPUTS}/$1/Compile/grammar.py \
    			     --dictionary_file ${CONTAINER_OUTPUTS}/$1/Compile/dict.json \
                             --time_budget 0.1 \
			     --host $1 \
			     --target_port $2 \
			     --no_ssl"
}

test_with_fuzzer-evomaster(){
    docker exec fuzzer-evomaster /bin/sh -c "java \
    	   -Xmx4G \
    	   -jar evomaster.jar \
	       --runningInDocker true \
	       --blackBox true \
               --maxTime 5m  \
   	       --problemType REST \
	       --outputFormat DEFAULT \
    	       --bbSwaggerUrl file://${FUZZER_SCHEMA_DIR}/$1.json \
    	       --bbTargetUrl http://$1:$2 \
	       --outputFolder ${CONTAINER_OUTPUTS}/$1"
}


test_with_fuzzer-schemathesis(){
    docker exec fuzzer-schemathesis /bin/sh -c "st run  \
    	   --url http://$1:$2 \
    	   --report har \
           --report-dir  ${CONTAINER_OUTPUTS}/${1} \
           ${FUZZER_SCHEMA_DIR}/$1.json"
}




test_with_fuzzer-marker(){
    docker exec fuzzer-marker /bin/sh -c "python ./test_fuzz.py  \
    	   --target http://$1:$2 \
           --out  ${CONTAINER_OUTPUTS}/${1} \
           --spec ${FUZZER_SCHEMA_DIR}/$1.json"
}
