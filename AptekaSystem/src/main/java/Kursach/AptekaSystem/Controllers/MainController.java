package Kursach.AptekaSystem.Controllers;

import lombok.Getter;
import lombok.Setter;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
@Setter
@Getter
public class MainController {

    public MainController() {}

    @GetMapping("/mainPage")
    public String showMainPage() {
        return "mainPage.html";
    }

    @GetMapping("/sale")
    public String showSale() {
        return "sale.html";
    }

    @GetMapping("/provider")
    public String showProvider() {
        return "provider.html";
    }

    @GetMapping("/client")
    public String showClient() {
        return "client.html";
    }

    @GetMapping("/employee")
    public String showEmployee() {
        return "employee.html";
    }
}
