package io.hawt;

import org.apache.camel.CamelContext;
import org.apache.camel.spring.boot.CamelContextConfiguration;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;

@SpringBootApplication
@ComponentScan(basePackages="io.hawt")
public class HelloWorldSpringBootApplication {

    /**
     * A main method to start this application.
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {
        SpringApplication.run(HelloWorldSpringBootApplication.class, args);
    }

    @Bean
    CamelContextConfiguration contextConfiguration() {
        return new CamelContextConfiguration() {

            @Override
            public void beforeApplicationStart(CamelContext context) {
                Utils.enableStatsAndInflightBrowse(context);
            }

            @Override
            public void afterApplicationStart(CamelContext camelContext) {
            }
        };
    }
}
