package io.hawt.router;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

import org.apache.camel.builder.RouteBuilder;
import org.springframework.stereotype.Component;

@Component
public class HelloWorldRouter extends RouteBuilder {

    @Override
    public void configure() {
      from("timer://foo?period=5000")  // Trigger every 5 seconds
        .setBody().simple("Hello, world!") // Change the Exchange Body to Hello world
        .to("log:mylogger"); // Use the Log component to write out the contents of the Exchange
    }
}
