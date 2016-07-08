{% raw %}FROM alpine

MAINTAINER Chris Jalinsky

RUN apk add --update go git

RUN mkdir /go
ENV GOPATH /go

# Get dependencies if necessary
#RUN go get gopkg.in/mgo.v2 && \
#    go get github.com/go-martini/martini && \
#    go get gopkg.in/redis.v3

ADD . /go/src/github.com/chrisjalinsky/httptemplates

RUN go install github.com/chrisjalinsky/httptemplates

WORKDIR "/go/src/github.com/chrisjalinsky/httptemplates"

ENTRYPOINT /go/bin/httptemplates

EXPOSE 8085{% endraw %}