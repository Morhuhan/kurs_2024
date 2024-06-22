package Kursach.AptekaSystem.Controllers;

import Kursach.AptekaSystem.DAO.DAO;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.Getter;
import lombok.Setter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@Setter
@Getter
public class MainRestController {

    private final DAO dao;
    private final ObjectMapper objectMapper;

    @Autowired
    public MainRestController(DAO dao, ObjectMapper objectMapper) {
        this.dao = dao;
        this.objectMapper = objectMapper;
    }

    @PostMapping("/getAllRecords")
    public ResponseEntity<?> getAllRecords(@RequestBody JsonNode jsonNode) {
        List<String> data = dao.getAllRecordsFromTable(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/getAllRecordsByAttribute")
    public ResponseEntity<?> getAllRecordsByAttribute(@RequestBody JsonNode jsonNode) {
        List<String> data = dao.getAllRecordsByAttribute(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/calculateFullPrice")
    public ResponseEntity<?> calculateFullPrice(@RequestBody JsonNode jsonNode) {
        List<String> data = dao.calculateFullPrice(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/getExpandedData")
    public ResponseEntity<?> getExpandedData(@RequestBody JsonNode jsonNode) {
        String data = dao.getExpandedData(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/addData")
    public ResponseEntity<?> addData(@RequestBody JsonNode jsonNode) {
        String data = dao.addDataToTable(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/editData")
    public ResponseEntity<?> editData(@RequestBody JsonNode jsonNode) {
        dao.editDataToTable(jsonNode);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/deleteData")
    public ResponseEntity<?> deleteData(@RequestBody JsonNode jsonNode) {
        dao.deleteDataFromTable(jsonNode);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/deleteClient")
    public ResponseEntity<?> deleteClient(@RequestBody JsonNode jsonNode) {
        dao.deleteClient(jsonNode);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/deleteEmployee")
    public ResponseEntity<?> deleteEmployee(@RequestBody JsonNode jsonNode) {
        dao.deleteEmployee(jsonNode);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/createSupply")
    public ResponseEntity<?> createSupply(@RequestBody JsonNode jsonNode) {
        dao.createSupply(jsonNode);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/createSale")
    public ResponseEntity<?> createSale(@RequestBody JsonNode jsonNode) {
        dao.createSale(jsonNode);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/createClient")
    public ResponseEntity<?> createClient(@RequestBody JsonNode jsonNode) {
        String data = dao.createClient(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/createEmployee")
    public ResponseEntity<?> createEmployee(@RequestBody JsonNode jsonNode) {
        String data = dao.createEmployee(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/createReportSupplies")
    public ResponseEntity<?> createReportSupplies(@RequestBody JsonNode jsonNode) {
        List<String> data = dao.createReportSupplies(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/createReportSales")
    public ResponseEntity<?> createReportSales(@RequestBody JsonNode jsonNode) {
        List<String> data = dao.createReportSales(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/checkSaleRecipe")
    public ResponseEntity<?> checkSaleRecipe(@RequestBody JsonNode jsonNode) {
        dao.checkSaleRecipe(jsonNode);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/checkPersonalCode")
    public ResponseEntity<?> checkPersonalCode(@RequestBody JsonNode jsonNode) {
        String data = dao.checkPersonalCode(jsonNode);
        return new ResponseEntity<>(data, HttpStatus.OK);
    }

    @PostMapping("/getAllBuyers")
    public ResponseEntity<?> getAllBuyers() {
        List<String> data = dao.getAllBuyers();
        return new ResponseEntity<>(data, HttpStatus.OK);
    }
}