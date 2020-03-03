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

static std::string parseIpString(std::string ipString) {
  char *ipStr = new char[ipString.length() + 1];
  strcpy(ipStr, ipString.c_str());
  const char *delimiter = ":";
  strtok(ipStr, delimiter);
  return strtok(NULL, delimiter);
}

// Logic and data behind the server's behavior.
class GreeterServiceImpl final : public Greeter::Service {
  Status SayHello(ServerContext* context, const HelloRequest* request,
                  HelloReply* reply) override {
    const std::string prefix("Hello ");
    reply->set_message(prefix + request->name());
    const std::string ip = parseIpString(context->peer());
    return Status::OK;
  }
};

void RunServer() {
  std::cout << "Starting server... " << std::endl;

  // NOTE: dont use `0.0.0.0` https://github.com/grpc/grpc/issues/10532
  // Failed to add :: listener, the environment may not support IPv6
  //std::string server_address("0.0.0.0:50051");
  std::string server_address("127.0.0.1:50051");

  // TODO: SslServerCredentials https://github.com/XunChangqing/grpc-authentication-sample/blob/master/event_server.cc

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