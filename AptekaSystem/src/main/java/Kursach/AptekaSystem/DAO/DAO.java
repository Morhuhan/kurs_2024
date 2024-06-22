package Kursach.AptekaSystem.DAO;

import com.fasterxml.jackson.databind.JsonNode;
import lombok.Getter;
import lombok.Setter;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@Setter
@Getter
public class DAO {

    private JdbcTemplate jdbcTemplate;

    public DAO(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<String> getAllRecordsFromTable(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "SELECT * FROM получить_записи(?::jsonb)";
        return jdbcTemplate.queryForList(sql, String.class, jsonString);
    }

    public List<String> getAllRecordsByAttribute(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "SELECT * FROM получить_записи_по_атрибуту(?::jsonb)";
        return jdbcTemplate.queryForList(sql, String.class, jsonString);
    }

    public List<String> calculateFullPrice(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "SELECT * FROM получить_полную_цену(?::jsonb)";
        return jdbcTemplate.queryForList(sql, String.class, jsonString);
    }

    public String getExpandedData(JsonNode jsonNode) throws DataAccessException {
        String jsonText = jsonNode.toString();
        String sql = "SELECT * FROM получить_дополнительные_данные(?::jsonb)";
        return jdbcTemplate.queryForObject(sql, String.class, jsonText);
    }

    public String addDataToTable(JsonNode jsonNode) throws DataAccessException  {
        String jsonString = jsonNode.toString();
        String sql = "SELECT * FROM добавить_запись_в_таблицу(?::jsonb)";
        return jdbcTemplate.queryForObject(sql, String.class, jsonString);
    }

    public String createClient(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "SELECT * FROM создать_клиента(?::jsonb)";
        return jdbcTemplate.queryForObject(sql, String.class, jsonString);
    }

    public List<String> createReportSupplies(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "SELECT * FROM сформировать_отчет_поставки(?::jsonb)";
        return jdbcTemplate.queryForList(sql, String.class, jsonString);
    }

    public List<String> createReportSales(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "SELECT * FROM сформировать_отчет_продажи(?::jsonb)";
        return jdbcTemplate.queryForList(sql, String.class, jsonString);
    }

    public String createEmployee(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "SELECT * FROM создать_сотрудника(?::jsonb)";
        return jdbcTemplate.queryForObject(sql, String.class, jsonString);
    }

    public void editDataToTable(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "CALL изменить_запись_в_таблице(?::jsonb)";
        jdbcTemplate.update(sql, jsonString);
    }

    public void deleteDataFromTable(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "CALL удалить_запись_из_таблицы(?::jsonb)";
        jdbcTemplate.update(sql, jsonString);
    }

    public void deleteClient(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "CALL удалить_клиента(?::jsonb)";
        jdbcTemplate.update(sql, jsonString);
    }

    public void deleteEmployee(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "CALL удалить_сотрудника(?::jsonb)";
        jdbcTemplate.update(sql, jsonString);
    }

    public void createSupply(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "CALL создать_поставку(?::jsonb)";
        jdbcTemplate.update(sql, jsonString);
    }

    public void createSale(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "CALL создать_продажу(?::jsonb)";
        jdbcTemplate.update(sql, jsonString);
    }

    public void checkSaleRecipe(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "CALL проверить_лекарства_по_рецепту(?::jsonb)";
        jdbcTemplate.update(sql, jsonString);
    }

    public String checkPersonalCode(JsonNode jsonNode) throws DataAccessException {
        String jsonString = jsonNode.toString();
        String sql = "SELECT * FROM проверить_персональный_код(?::jsonb)";
        return jdbcTemplate.queryForObject(sql, String.class, jsonString);
    }

    public List<String> getAllBuyers() throws DataAccessException {
        String sql = "SELECT * FROM получить_покупателей_и_их_скидки()";
        return jdbcTemplate.queryForList(sql, String.class);
    }
}