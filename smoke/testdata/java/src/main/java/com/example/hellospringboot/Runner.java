package com.example.hellospringboot;


import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class Runner implements CommandLineRunner {

    @Override
    public void run(String... args) throws Exception {
        log.info("hello from log");
    }
}
