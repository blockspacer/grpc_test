/*
 *
 * Copyright 2015, Google Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include <iostream>
#include <memory>
#include <string>

#include <grpc++/grpc++.h>

#include "emoji.grpc.pb.h"

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using helloworld::HelloRequest;
using helloworld::HelloReply;
using helloworld::Greeter;

// Logic and data behind the server's behavior.
class GreeterServiceImpl final : public Greeter::Service {
  Status SayHello(ServerContext* context, const HelloRequest* request,
                  HelloReply* reply) override {
    std::string prefix("Hello ");
    reply->set_message(prefix + request->name());
    return Status::OK;
  }
};

void RunServer() {
  std::cout << "Starting server... " << std::endl;

  std::string server_address("0.0.0.0:50051");
  GreeterServiceImpl service;

  ServerBuilder builder;
  // Listen on the given address without any authentication mechanism.
  builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
  // Register "service" as the instance through which we'll communicate with
  // clients. In this case it corresponds to an *synchronous* service.
  builder.RegisterService(&service);
  // Finally assemble the server.
  std::unique_ptr<Server> server(builder.BuildAndStart());
  if (!server) {
    std::cerr << "Server failed to listen on " << server_address << std::endl;
    return;
  }

  std::cout << "Server listening on " << server_address << std::endl;

  // Wait for the server to shutdown. Note that some other thread must be
  // responsible for shutting down the server for this call to ever return.
  server->Wait();
}

int main(int argc, char** argv) {
  RunServer();

  return 0;
}

#if 0
#include <grpcpp/grpcpp.h>
#include <iostream>
#include <memory>

#include "emoji.grpc.pb.h"
//#include "emoji.pb.h"

/*#include "NewsFeedDataAccessClient.h"
#include "PostsClient.h"*/

class AppService final : public proto::EmojiService::Service {
public:
    AppService() /*: nf_client(grpc::CreateChannel("news-feed-data-access:9000", grpc::InsecureChannelCredentials())),
                        posts_client(grpc::CreateChannel("posts:9000", grpc::InsecureChannelCredentials()))*/ {
    }


    ::grpc::Status InsertEmojis(::grpc::ServerContext* context
        , const ::proto::EmojiRequest* request
        , ::proto::EmojiResponse* response) override
    {
        std::string prefix("Hello again ");
        response->set_output_text(prefix + request->input_text());
        return::grpc::Status::OK;
    }

    /*Status SayHelloAgain(ServerContext* context, const HelloRequest* request,
                        HelloReply* reply) override {
        std::string prefix("Hello again ");
        reply->set_message(prefix + request->name());
        return Status::OK;
    }*/

    /*grpc::Status get_news_feed(grpc::ServerContext *context, const foobar::wall::WallQuery *request,
                               grpc::ServerWriter<foobar::posts::Post> *writer) override {
        const auto request_user = request->username();
        const auto request_limit = request->limit();
        const auto request_start = request->starting_id() < 0 ? 0 : request->starting_id();

        if (request_limit == 0 || request_start < 0 || request_user.empty()) {
            return grpc::Status::OK;
        }

        auto posts = this->nf_client.get_news_feed(*request);
        foobar::posts::Post p;
        while (posts->Read(&p)) {
            auto post = this->posts_client.fetch(p);
            writer->Write(post);
        }

        auto status = posts->Finish();
        return status;
    }*/

private:
//    NewsFeedDataAccessClient nf_client;
//    PostsClient posts_client;
};

int main(int argc, char* argv[]) {
    std::string server_address("0.0.0.0:9000");
    AppService app_service;

    grpc::ServerBuilder builder;
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    builder.RegisterService(&app_service);

    std::unique_ptr<grpc::Server> server(builder.BuildAndStart());
    std::cout << "News Feed server listening on " << server_address << std::endl;
    server->Wait();

    return 0;
}
#endif