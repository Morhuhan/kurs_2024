package Kursach.AptekaSystem.Controllers;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

@ControllerAdvice
public class GlobalExceptionHandler {

    private static final Map<String, String> sqlErrorMessages = new HashMap<>();

    static {
        sqlErrorMessages.put("23505", "Дублирование уникального значения.");
        sqlErrorMessages.put("23503", "Нарушение ограничения целостности данных (foreign key).");
        sqlErrorMessages.put("23502", "Нарушение ограничения NOT NULL.");
        sqlErrorMessages.put("23514", "Нарушение ограничения проверки (check constraint).");
        sqlErrorMessages.put("42501", "Нет прав на редактирование таблицы");
        sqlErrorMessages.put("22004", "Не найдено записей");
        sqlErrorMessages.put("P7772", "У поставщика нет указанного товара в таком количестве, или вы пытаетесь купить более 1000 товаров.");
    }

    @ExceptionHandler(SQLException.class)
    public ResponseEntity<Map<String, Object>> handleSQLException(SQLException e) {
        String errorCode = e.getSQLState();
        String errorMessage = sqlErrorMessages.getOrDefault(errorCode, e.getMessage());
        // Обрезаем текст ошибки
        errorMessage = ExceptionTrimmer(errorMessage);
        Map<String, Object> responseBody = new HashMap<>();
        responseBody.put("error", errorMessage);
        responseBody.put("status", HttpStatus.BAD_REQUEST.value());
        return new ResponseEntity<>(responseBody, HttpStatus.BAD_REQUEST);
    }

    private String ExceptionTrimmer(String errorMessage) {
        // Ищем индекс строки "Где: "
        int whereIndex = errorMessage.indexOf("Где: ");
        // Если "Где: " найдено в строке, обрезаем текст ошибки до этой позиции
        if (whereIndex != -1) {
            return errorMessage.substring(0, whereIndex).trim();
        }
        // Если не найдено, возвращаем оригинальное сообщение
        return errorMessage;
    }
}