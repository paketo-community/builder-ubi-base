package com.example.hellospringboot;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;
import java.text.SimpleDateFormat;
import java.util.Calendar;
@RestController
@Slf4j
public class HelloWorldController {

    @RequestMapping(path = "/helloWorld", method = RequestMethod.GET)
    public String helloWorld(
            @RequestParam(required = false) String firstName,
            @RequestParam(required = false) String lastName) {

        if (firstName != null && lastName != null) {
            return "Hello World" + firstName + " " + lastName;
        }
        return "Hello";
    }
    @GetMapping("/time")
    public  String time(){
        return new SimpleDateFormat("HH:mm:ss").format(Calendar.getInstance().getTime());
    }
    @RequestMapping(path = "/helloYou", method = RequestMethod.GET)
    public String helloYou(@RequestParam(required = false) String name){
        return "Hello" + name;
    }
}

