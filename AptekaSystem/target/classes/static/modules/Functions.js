// Модальные окна (общее)

function CreateOverlay(modal) {
    let overlay = document.getElementById('overlay');

    if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'overlay';
        document.body.appendChild(overlay);
    }

    let overlayStyle = window.getComputedStyle(overlay);

    if (overlayStyle.display === 'none') {
        overlay.style.display = 'block';
    }

    var modalZIndex = window.getComputedStyle(modal).zIndex;
    overlay.style.zIndex = parseInt(modalZIndex) - 1;
}

function CloseModal(modal) {
    modal.parentNode.removeChild(modal);

    var modals = document.querySelectorAll('.modal');
    var highestZIndex = 0;

    for (var i = 0; i < modals.length; i++) {
        var zIndex = parseInt(window.getComputedStyle(modals[i]).zIndex, 10);

        if (zIndex > highestZIndex) {
            highestZIndex = zIndex;
        }
    }

    var overlay = document.getElementById('overlay');

    if (overlay && modals.length > 0) {
        overlay.style.zIndex = highestZIndex - 1;
    } else if (overlay) {
        overlay.style.display = 'none';
    }
}

// Доступ

function ModalCreatePersonalCodeCheck() {
    // Создание модального окна
    const modal = document.createElement('div');
    modal.classList.add('modal');
    modal.id = 'modalCreateShift';  // Присвоение id модальному окну

    // Вызов функции для создания оверлея
    CreateOverlay(modal);

    // Создание заголовка модального окна
    const title = document.createElement('h1');
    title.textContent = 'Авторизация';
    modal.appendChild(title);

    // Создание формы
    const form = document.createElement('form');
    form.classList.add('form');

    // Создание инпута для табельного номера
    const employeeIdContainer = document.createElement('div');
    employeeIdContainer.classList.add('form-group');

    const employeeIdLabel = document.createElement('label');
    employeeIdLabel.htmlFor = 'employeeId';
    employeeIdLabel.textContent = 'Табельный номер';
    employeeIdContainer.appendChild(employeeIdLabel);

    const employeeIdInput = document.createElement('input');
    employeeIdInput.type = 'text';
    employeeIdInput.id = 'employeeId';
    employeeIdInput.name = 'employeeId';
    employeeIdInput.classList.add('form-control');
    employeeIdContainer.appendChild(employeeIdInput);

    form.appendChild(employeeIdContainer);

    // Создание инпута для персонального кода
    const personalCodeContainer = document.createElement('div');
    personalCodeContainer.classList.add('form-group');

    const personalCodeLabel = document.createElement('label');
    personalCodeLabel.htmlFor = 'personalCode';
    personalCodeLabel.textContent = 'Персональный код';
    personalCodeContainer.appendChild(personalCodeLabel);

    const personalCodeInput = document.createElement('input');
    personalCodeInput.type = 'password';
    personalCodeInput.id = 'personalCode';
    personalCodeInput.name = 'personalCode';
    personalCodeInput.classList.add('form-control');
    personalCodeContainer.appendChild(personalCodeInput);

    form.appendChild(personalCodeContainer);

    // Создание контейнера для кнопок
    const buttonContainer = document.createElement('div');
    buttonContainer.classList.add('container_buttons');

    // Кнопка "Продолжить"
    const submitButton = document.createElement('button');
    submitButton.type = 'button';  // Измените тип кнопки на 'button' для предотвращения отправки формы
    submitButton.textContent = 'Продолжить';
    submitButton.className = 'greenButton';
    submitButton.addEventListener('click', (event) => {
        event.preventDefault();
        CheckPersonalCode(employeeIdInput, personalCodeInput, modal);
    });

    // Кнопка "Закрыть"
    const closeButton = document.createElement('button');
    closeButton.type = 'button';
    closeButton.textContent = 'Закрыть';
    closeButton.className = 'redButton';
    closeButton.addEventListener('click', () => {
        window.location.href = '/mainPage';
    });

    // Добавление кнопок в контейнер
    buttonContainer.appendChild(submitButton);
    buttonContainer.appendChild(closeButton);

    // Добавление контейнера кнопок в форму
    form.appendChild(buttonContainer);

    modal.appendChild(form);

    // Добавление модального окна в body
    document.body.appendChild(modal);
}

function CheckPersonalCode(employeeIdInput, personalCodeInput, modal) {

    // Формирование JSON
    const data = {
        employeeId: employeeIdInput.value,
        personalCode: personalCodeInput.value
    };

    // Отправка запроса на сервер
    fetch('/checkPersonalCode', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })
    .then(responseData => {
        const accessLevel = responseData.accessLevel;
        LoadPage(accessLevel, modal);
        CloseModal(modal);
    })
    .catch(error => {
        alert(error.message);
    });
}

function LoadPage(securityLevel, modal) {
    // Получение текущего URL
    const currentUrl = window.location.href;
    let accessAllowed = false;

    // Анализ текущего URL и уровня доступа
    switch (true) {

        case currentUrl.includes('/sale'):
            if (securityLevel >= 1) {
                ShiftCreate(modal);
                var productsTable = document.getElementById('productsTable');
                var salesTable = document.getElementById('salesTable');
                var buyersModule = document.getElementById('buyersModule');
                var productsSelect = document.getElementById('productsSelect');
                UpdateSalePage(productsTable, salesTable, buyersModule, productsSelect);
            } else {
                alert("Недостаточно прав для доступа к этой странице.");
                window.location.href = '/mainPage';
            }
            break;

        case currentUrl.includes('/provider'):
            if (securityLevel >= 2) {
                var providersTable = document.getElementById('providersTable');
                var providersSelect = document.getElementById('providersSelect');
                UpdateTable(providersTable).then(() => {
                    AddSortingToTableHeaders(providersTable);
                    AttachRowClick(providersTable, ModalCreateSupply);
                    HideColumns(providersTable);
                    FillSearchSelectOptions(providersSelect, providersTable);
                })
            } else {
                alert("Недостаточно прав для доступа к этой странице.");
                window.location.href = '/mainPage';
            }
            break;

        case currentUrl.includes('/client'):
            if (securityLevel >= 2) {
                var clientsTable = document.getElementById('clientsTable');
                var clientsSelect = document.getElementById('clientsSelect');
                UpdateTable(clientsTable).then(() => {
                    AddSortingToTableHeaders(clientsTable);
                    AttachSelectAbility(clientsTable);
                    HideColumns(clientsTable);
                    FillSearchSelectOptions(clientsSelect, clientsTable);
                })
            } else {
                alert("Недостаточно прав для доступа к этой странице.");
                window.location.href = '/mainPage';
            }
            break;

        case currentUrl.includes('/employee'):
            if (securityLevel >= 3) {
                var employeeTable = document.getElementById('employeeTable');
                var employeeSelect = document.getElementById('employeeSelect');
                UpdateTable(employeeTable).then(() => {
                    AttachSelectAbility(employeeTable);
                    AddSortingToTableHeaders(employeeTable);
                    HideColumns(employeeTable);
                    FillSearchSelectOptions(employeeSelect, employeeTable);
                })
            } else {
                alert("Недостаточно прав для доступа к этой странице.");
                window.location.href = '/mainPage';
            }
            break;


        // Добавьте другие URL и их требования к уровню доступа по аналогии
        default:
            alert("Недостаточно прав для доступа к этой странице.");
            window.location.href = '/mainPage';
            break;
    }
}

// Продажа

function UpdateSalePage(productsTable, salesTable, buyersModule, productsSelect) {
    UpdateTable(productsTable).then(() => {
        AddSortingToTableHeaders(productsTable);
        AddSortingToTableHeaders(salesTable);
        AddCheckboxColumn(productsTable);
        AddCheckboxColumn(salesTable);
        CalculateFullPrice(productsTable);
        UpdateBuyersModule(buyersModule);
        HideColumns(salesTable);
        HideColumns(productsTable);
        FillSearchSelectOptions(productsSelect, productsTable);
    });
}

function SalesAddButtonClick(productTable, salesTable, recipesTable) {
    // Найти индекс столбца с заголовком "ид_лекарства" в таблице продуктов
    const productHeaderCells = productTable.querySelectorAll('thead tr th');
    let productIndex = -1;
    productHeaderCells.forEach((headerCell, index) => {
        if (headerCell.getAttribute('name') === 'ид_лекарства') {
            productIndex = index;
        }
    });

    // Если индекс не найден, прекращаем выполнение
    if (productIndex === -1) {
        alert("Не найден столбец 'ид_лекарства' в таблице продуктов.");
        return;
    }

    // Найти индекс столбца с заголовком "ид_каталога" в таблице рецептов
    const recipeHeaderCells = recipesTable.querySelectorAll('thead tr th');
    let recipeIndex = -1;
    recipeHeaderCells.forEach((headerCell, index) => {
        if (headerCell.getAttribute('name') === 'ид_каталога') {
            recipeIndex = index;
        }
    });

    // Если индекс не найден, прекращаем выполнение
    if (recipeIndex === -1) {
        alert("Не найден столбец 'ид_каталога' в таблице рецептов.");
        return;
    }

    // Собираем все идентификаторы продуктов из отмеченных строк таблицы продуктов
    const productRows = Array.from(productTable.querySelectorAll('tbody tr'));
    const checkedProducts = [];

    productRows.forEach(row => {
        const checkbox = row.querySelector('td:last-child input[type="checkbox"]');
        if (checkbox && checkbox.checked) {
            const productIDCell = row.children[productIndex];
            if (productIDCell) {
                checkedProducts.push(productIDCell.textContent.trim());
            }
        }
    });

    // Если нет выделенных продуктов, прекращаем выполнение
    if (checkedProducts.length === 0) {
        alert("Нет выбранных продуктов.");
        return;
    }

    // Собираем идентификаторы рецептов из таблицы рецептов
    const recipeRows = Array.from(recipesTable.querySelectorAll('tbody tr'));
    const recipeIDs = recipeRows.map(row => row.children[recipeIndex].textContent.trim());

    // Формируем JSON объект для запроса
    const requestData = {
        productIds: checkedProducts,
        recipeIds: recipeIDs
    };

    // Отправляем запрос на сервер
    fetch('/checkSaleRecipe', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestData),
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }

        // Переносим строки из `productTable` в `salesTable`
        productRows.forEach(row => {
            const checkbox = row.querySelector('td:last-child input[type="checkbox"]');
            if (checkbox && checkbox.checked) {
                const cloneRow = row.cloneNode(true);
                const clonedCheckbox = cloneRow.querySelector('td:last-child input[type="checkbox"]');
                if (clonedCheckbox) {
                    clonedCheckbox.checked = false;
                }
                salesTable.querySelector('tbody').appendChild(cloneRow);
                row.remove();
            }
        });

        // Вызываем функцию для обновления итоговой суммы продажи
        UpdateTotalSumSale();

    })
    .catch(error => {
        alert(error.message);
    });
}

function SalesDeleteButtonClick(productTable, salesTable) {
    const salesRows = salesTable.querySelectorAll('tbody tr');

    salesRows.forEach(row => {
        const checkboxCell = row.querySelector('td:last-child input[type="checkbox"]');

        if (checkboxCell && checkboxCell.checked) {
            const cloneRow = row.cloneNode(true);

            const clonedCheckboxCell = cloneRow.querySelector('td:last-child input[type="checkbox"]');
            if (clonedCheckboxCell) {
                clonedCheckboxCell.checked = false;
            }

            productTable.querySelector('tbody').appendChild(cloneRow);

            row.remove();
        }
    });

    // Вызываем функцию для обновления итоговой суммы продажи
    UpdateTotalSumSale();
}

function CalculateFullPrice(table) {
    // Находим хедеры таблиц для ид_лекарства и цена
    const idColumnIndex = Array.from(table.querySelectorAll('th')).findIndex(th => th.getAttribute('name') === 'ид_лекарства');
    const priceColumnIndex = Array.from(table.querySelectorAll('th')).findIndex(th => th.getAttribute('name') === 'цена');

    // Получаем массив ид_лекарств из таблицы
    const ids = Array.from(table.querySelectorAll('tr td:nth-child(' + (idColumnIndex + 1) + ')'))
                    .map(td => parseInt(td.textContent.trim()));

    // Создаем JSON с массивом ид_лекарств
    const payload = {
        'ид_лекарств': ids
    };

    // Отправляем запрос на сервер с использованием fetch
    fetch("/calculateFullPrice", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify(payload)
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })
    .then(responseData => {
        // Извлекаем из responseData массив ид_лекарства и полная_стоимость
        responseData.forEach(itemStr => {
            const item = JSON.parse(itemStr); // Десериализуем строку JSON в объект
            const id = item.ид_лекарства;
            const fullPrice = item.полная_стоимость;

            // Находим соответствующую строчку и обновляем значение ячейки с ценой
            Array.from(table.querySelectorAll('tr')).forEach(tr => {
                const idCell = tr.cells[idColumnIndex];
                const priceCell = tr.cells[priceColumnIndex];

                if (idCell && priceCell && parseInt(idCell.textContent.trim()) === id) {
                    priceCell.textContent = fullPrice;
                }
            });
        });
    })
    .catch(error => {
        alert(error.message);
    });
}

function GenerateRandomRecipe(table) {

    // Формируем JSON для запроса
    const requestData = {
        tablename: "каталог",
        attributes: {
            "по_рецепту": "true"
        }
    };

    // Отправляем fetch запрос
    fetch('/getAllRecordsByAttribute', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestData)
    })

    .then(response => {
        // Проверяем успешность ответа
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })

    .then(data => {
        // Проверяем, что data является массивом
        if (Array.isArray(data)) {

            // Находим tbody в таблице
            const tbody = table.querySelector('tbody');

            // Очищаем tbody перед добавлением новых записей
            while (tbody.rows.length > 0) {
                tbody.deleteRow(0);
            }

            // Получаем имена заголовков таблицы
            const headers = Array.from(table.rows[0].cells).map(cell => cell.getAttribute('name'));

            // Выбираем случайное число от 3 до 5
            const randomCount = Math.floor(Math.random() * 3) + 3;

            // Определяем количество записей
            const totalRecords = data.length;

            // Генерируем случайные индексы
            let randomIndexes = [];
            while (randomIndexes.length < randomCount) {
                const randomIndex = Math.floor(Math.random() * totalRecords);
                if (!randomIndexes.includes(randomIndex)) {
                    randomIndexes.push(randomIndex);
                }
            }

            // Добавляем новые записи в tbody
            randomIndexes.forEach(index => {
                const recordStr = data[index];
                const record = JSON.parse(recordStr);
                const row = tbody.insertRow();

                headers.forEach(header => {
                    const cell = row.insertCell();
                    cell.textContent = record[header] || '';
                });
            });
        } else {
            console.error('Некорректный формат данных от сервера');
        }
    })
    .catch(error => {
        alert(error.message);
    });
}

function ModalCreateCatalog() {
    // Создание модального окна
    const modal = document.createElement('div');
    modal.classList.add('modal');
    modal.id = 'modalCreateCatalog';  // Присвоение id модальному окну

    // Вызов функции для создания оверлея
    CreateOverlay(modal);

    // Создание заголовка модального окна
    const title = document.createElement('h1');
    title.textContent = 'Каталог лекарств';
    modal.appendChild(title);

    // Создание таблицы
    const table = document.createElement('table');
    table.classList.add('table');

    // Создание заголовков таблицы
    const thead = document.createElement('thead');
    const headerRow = document.createElement('tr');

    const headers = ['Название', 'Производитель'];
    headers.forEach(text => {
        const th = document.createElement('th');
        th.textContent = text;
        headerRow.appendChild(th);
    });

    thead.appendChild(headerRow);
    table.appendChild(thead);

    // Создание тела таблицы
    const tbody = document.createElement('tbody');
    table.appendChild(tbody);

    modal.appendChild(table);

    // Создание кнопки закрытия
    const closeButton = document.createElement('button');
    closeButton.textContent = 'Закрыть';
    closeButton.className = 'redButton';
    closeButton.addEventListener('click', () => CloseModal(modal));
    modal.appendChild(closeButton);

    // Добавление модального окна в body
    document.body.appendChild(modal);

    // Fetch запрос для получения данных
    fetch('/getAllRecords', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ tablename: 'каталог' })
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })
    .then(data => {
        Object.values(data).forEach(recordString => {
            // Преобразование JSON-строки в объект
            const record = JSON.parse(recordString);
            populateTable(record);
        });
    })
    .catch(error => {
        alert(error.message);
    });

    // Функция для заполнения таблицы данными
    function populateTable(record) {
        const row = document.createElement('tr');

        const nameCell = document.createElement('td');
        nameCell.textContent = record.название || '';
        row.appendChild(nameCell);

        const manufacturerCell = document.createElement('td');
        manufacturerCell.textContent = record.производитель || '';
        row.appendChild(manufacturerCell);

        tbody.appendChild(row);
    }
}

function ModalCreateRecipeSubmit(modal) {
    const inputs = modal.querySelectorAll('input:not([type="radio"])');

    const standardFormData = {
        серия: '',
        номер: '',
        дней_действует: '',
        дата_выдачи: '',
        tablename: 'Рецепт'
    };

    const narcoticFormData = {
        фамилия_пациента: '',
        имя_пациента: '',
        отчество_пациента: '',
        др_пациента: '',
        номер_медкарты: '',
        фамилия_врача: '',
        имя_врача: '',
        отчество_врача: '',
        медорганизация: '',
        tablename: 'Наркорецепт',
        ид_рецепта: ''
    };

    inputs.forEach(input => {
        if (standardFormData.hasOwnProperty(input.name)) {
            standardFormData[input.name] = input.value;
        }
        if (narcoticFormData.hasOwnProperty(input.name)) {
            narcoticFormData[input.name] = input.value;
        }
    });

    // Отправляем запрос с tablename = 'Рецепт'
    fetch('/addData', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(standardFormData)
    })
    .then(response => response.json())
    .then(data => {
        console.log('Success:', data);

        const radioNarcotic = modal.querySelector('#narcotic');

        // Если выбрана радиокнопка "Наркорецепт"
        if (radioNarcotic.checked) {
            narcoticFormData.ид_рецепта = data.ид_рецепта;

            return fetch('/addData', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(narcoticFormData)
            });
        }

        return Promise.resolve(null);
    })
    .then(response => {
        if (response) {
            return response.json();
        }
        return null;
    })
    .then(data => {
        if (data) {
            console.log('Narcotic Success:', data);
        }
        alert('Форма успешно отправлена!');
    })
    .catch((error) => {
        alert(error.message);
    });

    // Закрыть модальное окно
    CloseModal(modal);
}

function ToggleShiftInfo() {
    var menu = document.getElementById("shiftMenu");
    var button = document.getElementById("shiftInfoButton");
    var rect = button.getBoundingClientRect();

    if (menu.style.display === "none" || menu.style.display === "") {
        menu.style.display = "block";
        menu.style.top = rect.bottom + "px";
        menu.style.left = rect.left + "px";
    } else {
        menu.style.display = "none";
    }
}

function ShiftCreate(modal) {
    const employeeIdInput = modal.querySelector('#employeeId');
    const employeeId = employeeIdInput.value;

    const shiftMenu = document.getElementById('shiftMenu');

    if (shiftMenu) {
        const employeeNumberField = shiftMenu.querySelector('#employeeNumber');
        employeeNumberField.value = employeeId;

        const startTimeField = shiftMenu.querySelector('#startTime');
        InputTodayTimestamp(startTimeField);

        const timePassedField = shiftMenu.querySelector('#timePassed');
        StartTimer(timePassedField);

        const payload = {
            tableName: 'смена',
            ид_сотрудника: employeeId,
            время_начала: startTimeField.value
        };

        // Отправляем запрос на сервер с использованием fetch
        fetch("/addData", {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify(payload)
        })
        .then(response => {
            if (response.ok) {
                return response.json();
            }
        })
        .then(responseData => {

            const shiftId = responseData.ид_смены;

            const shiftIdField = shiftMenu.querySelector('#shiftId');
            if (shiftIdField) {
                shiftIdField.value = shiftId;
            }
        })
        .catch(error => {
            console.error('Ошибка при получении данных от сервера: ', error.message);
        });
    }
}

function CloseShift() {
    if (confirm("Вы уверены что хотите завершить смену?")) {
        const shiftMenu = document.getElementById('shiftMenu'); // Получаем shiftMenu элемент

        if (shiftMenu) {
            // Извлекаем значение из input поля shiftId
            const shiftIdField = shiftMenu.querySelector('#shiftId');
            const shiftId = shiftIdField.value;

            // Извлекаем значение из input поля startTime
            const startTimeField = shiftMenu.querySelector('#startTime');
            const startTime = startTimeField.value;

            // Извлекаем значение из input поля timePassed
            const timePassedField = shiftMenu.querySelector('#timePassed');
            const timePassed = timePassedField.value;

            // Вычисляем resultTimestamp
            const resultTimestamp = CalculateTime(startTime, timePassed);

            // Подготавливаем данные для отправки
            const payload = {
                tableName: 'смена',
                ид_смены: shiftId,
                время_конца: resultTimestamp
            };

            // Отправляем запрос на сервер с использованием fetch
            fetch("/editData", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify(payload)
            })
            .then(response => {
                if (response.ok) {
                    console.log('Данные успешно отправлены на сервер');
                    window.location.href = '/mainPage';
                } else {
                    throw new Error('Ошибка при отправке данных на сервер: ' + response.statusText);
                }
            })
            .catch(error => {
                console.error('Ошибка при отправке данных на сервер: ', error.message);
            });
        } else {
            console.error('Не удалось найти элемент shiftMenu.');
        }
    } else {
        console.log('Завершение смены отменено пользователем.');
    }
}

function SubmitSaleClick(salesTable, totalSumShift, totalSumSales, totalSumSalesWithDiscount, buyersModule) {
    // Найти индекс столбца с заголовком "ид_лекарства" в таблице продаж
    const salesHeaderCells = salesTable.querySelectorAll('thead tr th');
    let salesIndex = -1;
    let priceIndex = -1; // Индекс столбца с ценами

    salesHeaderCells.forEach((headerCell, index) => {
        if (headerCell.getAttribute('name') === 'ид_лекарства') {
            salesIndex = index;
        }
        if (headerCell.getAttribute('name') === 'цена') {
            priceIndex = index;
        }
    });

    // Если индексы не найдены, прекращаем выполнение
    if (salesIndex === -1) {
        alert("Не найден столбец 'ид_лекарства' в таблице продаж.");
        return;
    }
    if (priceIndex === -1) {
        alert("Не найден столбец 'цена' в таблице продаж.");
        return;
    }

    // Собираем все идентификаторы продуктов из строк таблицы продаж
    const salesRows = Array.from(salesTable.querySelectorAll('tbody tr'));
    const saleProductIds = salesRows.map(row => row.children[salesIndex].textContent.trim());

    // Если таблица продаж пуста, прекращаем выполнение
    if (saleProductIds.length === 0) {
        alert("Нет продуктов в таблице продаж.");
        return;
    }

    // Находим shiftId и получаем его value
    const shiftId = shiftMenu.querySelector('[id="shiftId"]').value;

    // Находим timePassed и startTime и получаем их значения
    const timePassed = shiftMenu.querySelector('[id="timePassed"]').value;
    const startTime = shiftMenu.querySelector('[id="startTime"]').value;

    // Вычисляем итоговое время с помощью функции CalculateTime
    const resultTimestamp = CalculateTime(startTime, timePassed);

    // Находим идентификатор персоны из модуля покупателей
    const personaSelect = buyersModule.querySelector('[id="personaSelect"]');
    const personId = personaSelect ? personaSelect.value : null;

    // Формируем JSON объект для запроса
    const requestData = {
        productIds: saleProductIds,
        shiftId: shiftId,
        time: resultTimestamp,
        personId: personId
    };

    fetch('/createSale', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestData),
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }

        alert("Продажа успешно создана.");

        // Исправлено: Проверка на пустые значения и преобразование к числу
        const totalShift = parseFloat(totalSumShift.value) || 0;
        const totalSalesWithDiscount = parseFloat(totalSumSalesWithDiscount.value) || 0;

        totalSumShift.value = (totalShift + totalSalesWithDiscount).toFixed(2);

        // Удаляем все строки из таблицы salesTable
        salesRows.forEach(row => {
            row.remove();
        });

        totalSumSales.value = '';
        totalSumSalesWithDiscount.value = '';
    })
    .catch(error => {
        alert(error.message);
    });
}

function UpdateBuyersModule(buyersModule) {
    // Отправляем запрос на сервер с использованием fetch
    fetch("/getAllBuyers", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        }
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })
    .then(responseData => {
        // Находим элемент с id personaSelect и input с id discount
        const personaSelect = buyersModule.querySelector('#personaSelect');
        const discountInput = buyersModule.querySelector('#discount');

        // Очищаем текущее содержимое personaSelect
        personaSelect.innerHTML = '';

        // Создаем элемент option со значением по умолчанию
        const defaultOption = document.createElement('option');
        defaultOption.value = '';
        defaultOption.textContent = '-';
        personaSelect.appendChild(defaultOption);

        // Добавляем каждый покупатель в personaSelect
        responseData.forEach(itemStr => {
            const item = JSON.parse(itemStr); // Десериализуем строку JSON в объект
            const { ид_персоны, фамилия, имя, отчество, скидка } = item;

            // Создаем новый элемент option для каждого покупателя
            const option = document.createElement('option');
            option.value = ид_персоны;
            option.textContent = `${фамилия} ${имя} ${отчество}`;
            option.dataset.discount = скидка;  // Сохраняем скидку в data-атрибут

            // Добавляем option в personaSelect
            personaSelect.appendChild(option);
        });

        // По умолчанию устанавливаем значение скидки на "-"
        discountInput.value = '-';

        // Событие при смене выбранного option
        personaSelect.addEventListener('change', function () {
            const selectedOption = personaSelect.options[personaSelect.selectedIndex];
            if (selectedOption && selectedOption.value) {
                discountInput.value = selectedOption.dataset.discount;
            } else {
                discountInput.value = '-';
            }

            // Вручную вызываем событие change, чтобы UpdateTotalSumSale был вызван
            const event = new Event('change');
            discountInput.dispatchEvent(event);
        });
    })
    .catch(error => {
        alert(error.message);
    });
}

function UpdateTotalSumSale() {
    // Находим таблицу salesTable по ID
    const salesTable = document.getElementById('salesTable');
    // Находим поле ввода скидки discount по ID
    const discountInput = document.getElementById('discount');
    // Находим поле для вывода общей суммы totalSumSales по ID
    const totalSumInput = document.getElementById('totalSumSales');
    // Находим поле для вывода общей суммы с учетом скидки totalSumSalesWithDiscount по ID
    const totalSumWithDiscountInput = document.getElementById('totalSumSalesWithDiscount');

    // Находим индекс столбца с заголовком "цена" в таблице salesTable
    const salesHeaderCells = salesTable.querySelectorAll('thead tr th');
    let priceIndex = -1;

    salesHeaderCells.forEach((headerCell, index) => {
        if (headerCell.getAttribute('name') === 'цена') {
            priceIndex = index;
        }
    });

    // Если индекс не найден, прекращаем выполнение
    if (priceIndex === -1) {
        alert("Не найден столбец 'цена' в таблице продаж.");
        return;
    }

    // Суммируем значения в колонке "цена"
    const salesRows = Array.from(salesTable.querySelectorAll('tbody tr'));
    let totalSum = salesRows.reduce((sum, row) => {
        const priceCell = row.children[priceIndex];
        return sum + parseFloat(priceCell.textContent.trim());
    }, 0);

    // Округляем сумму до целого числа
    totalSum = Math.round(totalSum);

    // Обновляем поле totalSumInput
    totalSumInput.value = totalSum;

    // Получаем значение скидки из discountInput
    let discount = parseFloat(discountInput.value);

    // Если значение скидки невалидное или отрицательное, устанавливаем скидку в 0%
    if (isNaN(discount) || discount < 0) {
        discount = 0;
    }

    // Вычисляем итоговую сумму с учетом скидки
    const totalSumWithDiscount = totalSum - (totalSum * (discount / 100));

    // Округляем итоговую сумму до целого числа и обновляем поле totalSumWithDiscountInput
    totalSumWithDiscountInput.value = Math.round(totalSumWithDiscount);
}

// Поставка

function ModalCreateSupply(event) {

    const clickedRow = event;

    // Если даже в этом случае не удается получить строку, выбрасываем ошибку
    if (!clickedRow || clickedRow.tagName !== 'TR') {
        console.error('Не удалось найти строку таблицы.');
        return;
    }

    // Получаем заголовки таблицы
    const table = clickedRow.closest('table');
    if (!table) {
        console.error('Не удалось найти таблицу, содержащую строку.');
        return;
    }
    const headers = table.querySelectorAll('th');

    let supplierHeader, medicineHeader, manufacturerHeader, wholesalePriceHeader, catalogIdHeader, providerIdHeader, providerCountHeader;

    headers.forEach(header => {
        if (header.getAttribute('name') === 'название') {
            supplierHeader = header;
        }
        if (header.getAttribute('name') === 'оптовая_цена') {
            wholesalePriceHeader = header;
        }
        if (header.getAttribute('name') === 'ид_поставщика') {
            providerIdHeader = header;
        }
        if (header.getAttribute('name') === 'количество') {
            providerCountHeader = header;
        }
    });

    headers.forEach(header => {
        const expandedColumns = header.getAttribute('data-expanded-columns');
        if (expandedColumns && expandedColumns === 'название') {
            medicineHeader = header;
        }
        if (expandedColumns && expandedColumns === 'производитель') {
            manufacturerHeader = header;
        }
        if (expandedColumns && expandedColumns === 'ид_каталога') {
            catalogIdHeader = header;
        }
    });

    if (!providerIdHeader || !catalogIdHeader || !supplierHeader || !medicineHeader || !manufacturerHeader || !wholesalePriceHeader) {
        console.error('Не удалось найти необходимые заголовки в таблице.');
        return;
    }

    // Ищем индексы заголовков
    let supplierIndex, medicineIndex, manufacturerIndex, wholesalePriceIndex, catalogIdIndex, providerIdIndex, providerCountIndex;
    headers.forEach((header, index) => {
        if (header === supplierHeader) supplierIndex = index;
        if (header === medicineHeader) medicineIndex = index;
        if (header === manufacturerHeader) manufacturerIndex = index;
        if (header === wholesalePriceHeader) wholesalePriceIndex = index;
        if (header === catalogIdHeader) catalogIdIndex = index;
        if (header === providerIdHeader) providerIdIndex = index;
        if (header === providerCountHeader) providerCountIndex = index;
    });

    // Получаем данные из ячеек строки
    const cells = clickedRow.querySelectorAll('td');
    const supplierData = cells[supplierIndex].textContent.trim();
    const medicineData = cells[medicineIndex].textContent.trim();
    const manufacturerData = cells[manufacturerIndex].textContent.trim();
    const wholesalePriceData = parseFloat(cells[wholesalePriceIndex].textContent.trim());
    const catalogIdData = cells[catalogIdIndex].textContent.trim();
    const providerIdData = cells[providerIdIndex] ? cells[providerIdIndex].textContent.trim() : '';
    const providerCountData = cells[providerCountIndex] ? cells[providerCountIndex].textContent.trim() : '';

    // Создание модального окна
    const modal = document.createElement('div');
    modal.classList.add('modal');
    modal.id = 'modalCreateSupply';

    // Вызов функции для создания оверлея
    CreateOverlay(modal);

    // Создание заголовка модального окна
    const title = document.createElement('h1');
    title.textContent = 'Создание поставки';
    modal.appendChild(title);

    // Создание формы для инпутов
    const form = document.createElement('form');

    // Инпут для Поставщик (disabled)
    const supplierLabel = document.createElement('label');
    supplierLabel.textContent = 'Поставщик:';
    form.appendChild(supplierLabel);

    const supplierInput = document.createElement('input');
    supplierInput.type = 'text';
    supplierInput.name = 'supplier';
    supplierInput.value = supplierData;
    supplierInput.disabled = true;
    form.appendChild(supplierInput);

    // Инпут для Лекарство (disabled)
    const medicineLabel = document.createElement('label');
    medicineLabel.textContent = 'Лекарство:';
    form.appendChild(medicineLabel);

    const medicineInput = document.createElement('input');
    medicineInput.type = 'text';
    medicineInput.name = 'medicine';
    medicineInput.value = medicineData;
    medicineInput.disabled = true;
    form.appendChild(medicineInput);

    // Инпут для Производитель (disabled)
    const manufacturerLabel = document.createElement('label');
    manufacturerLabel.textContent = 'Производитель:';
    form.appendChild(manufacturerLabel);

    const manufacturerInput = document.createElement('input');
    manufacturerInput.type = 'text';
    manufacturerInput.name = 'manufacturer';
    manufacturerInput.value = manufacturerData;
    manufacturerInput.disabled = true;
    form.appendChild(manufacturerInput);

    // Инпут для в наличии (disabled)
    const providerCountLabel = document.createElement('label');
    providerCountLabel.textContent = 'В наличии:';
    form.appendChild(providerCountLabel);

    const providerCountInput = document.createElement('input');
    providerCountInput.type = 'text';
    providerCountInput.name = 'provider_count';
    providerCountInput.value = providerCountData;
    providerCountInput.disabled = true;
    form.appendChild(providerCountInput);

    // Инпут для наценки
    const markupLabel = document.createElement('label');
    markupLabel.textContent = 'Наценка в процентах:';
    form.appendChild(markupLabel);

    const markupInput = document.createElement('input');
    markupInput.type = 'number';
    markupInput.name = 'markup';
    markupInput.required = true;
    form.appendChild(markupInput);

    // Инпут для Итоговой цены (disabled)
    const finalPriceLabel = document.createElement('label');
    finalPriceLabel.textContent = 'Итоговая цена:';
    form.appendChild(finalPriceLabel);

    const finalPriceInput = document.createElement('input');
    finalPriceInput.type = 'text';
    finalPriceInput.name = 'final_price';
    finalPriceInput.value = wholesalePriceData.toFixed(2); // Изначально там указана просто оптовая_цена
    finalPriceInput.disabled = true;
    form.appendChild(finalPriceInput);

    // Инпут для даты
    const dateLabel = document.createElement('label');
    dateLabel.textContent = 'Дата:';
    form.appendChild(dateLabel);

    const dateInput = document.createElement('input');
    dateInput.type = 'date';
    dateInput.name = 'date';
    dateInput.required = true;
    InputTodayDate(dateInput);
    form.appendChild(dateInput);

    // Инпут для количества
    const quantityLabel = document.createElement('label');
    quantityLabel.textContent = 'Количество:';
    form.appendChild(quantityLabel);

    const quantityInput = document.createElement('input');
    quantityInput.type = 'number';
    quantityInput.name = 'quantity';
    quantityInput.required = true;
    form.appendChild(quantityInput);

    // Скрытые поля для ID по каталогу и ID поставщика
    const catalogIdInput = document.createElement('input');
    catalogIdInput.type = 'hidden';
    catalogIdInput.name = 'catalog_id';
    catalogIdInput.value = catalogIdData;
    form.appendChild(catalogIdInput);

    const providerIdInput = document.createElement('input');
    providerIdInput.type = 'hidden';
    providerIdInput.name = 'provider_id';
    providerIdInput.value = providerIdData;
    form.appendChild(providerIdInput);

    // Добавление формы в модальное окно
    modal.appendChild(form);

    // Создание контейнера для кнопок
    const buttonContainer = document.createElement('div');
    buttonContainer.classList.add('container_buttons');

    // Создание кнопки ОК
    const okButton = document.createElement('button');
    okButton.textContent = 'ОК';
    okButton.className = 'greenButton';
    okButton.addEventListener('click', () => SubmitSupplyCreateClick(modal));
    buttonContainer.appendChild(okButton);

    // Создание кнопки закрытия
    const closeButton = document.createElement('button');
    closeButton.textContent = 'Закрыть';
    closeButton.className = 'redButton';
    closeButton.addEventListener('click', () => CloseModal(modal));
    buttonContainer.appendChild(closeButton);

    // Добавление контейнера с кнопками в модальное окно
    modal.appendChild(buttonContainer);

    // Добавление модального окна в body
    document.body.appendChild(modal);

    // Добавляем EventListener для изменения итоговой цены при изменении наценки
    markupInput.addEventListener('input', () => {
        const markup = parseFloat(markupInput.value);
        if (!isNaN(markup)) {
            const finalPrice = wholesalePriceData + (wholesalePriceData * markup / 100);
            finalPriceInput.value = finalPrice.toFixed(2);
        } else {
            finalPriceInput.value = wholesalePriceData.toFixed(2);
        }
    });
}

function SubmitSupplyCreateClick(modal) {
    const inputs = modal.querySelectorAll('input');

    const formData = {
        catalog_id: '',
        provider_id: '',
        final_price: '',
        date: '',
        markup: '',
        quantity: ''
    };

    inputs.forEach(input => {
        if (formData.hasOwnProperty(input.name)) {
            formData[input.name] = input.value;
        }
    });

    fetch('/createSupply', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        alert('Поставка успешно создана.');
    })
    .catch((error) => {
        console.error('Error:', error);
        // Показываем ошибку в alert
        alert('Error: ' + error.message);
    });

    // Закрыть модальное окно
    CloseModal(modal);
}

// Клиенты

function ModalCreateClient(clientsTable) {

    // Создаем модальное окно
    const modal = document.createElement('div');
    modal.classList.add('modal');
    modal.id = 'modalCreateClient';

    // Вызов функции для создания оверлея
    CreateOverlay(modal);

    // Создание заголовка модального окна
    const title = document.createElement('h1');
    title.textContent = 'Создание клиента';
    modal.appendChild(title);

    // Создание формы для инпутов
    const form = document.createElement('form');

    // Создание контейнеров для различных частей формы
    const personalInfoContainer = document.createElement('div');
    personalInfoContainer.classList.add('personalInfo');

    const clientInfoContainer = document.createElement('div');
    clientInfoContainer.classList.add('clientInfo');

    // Инпут для Фамилия
    const lastNameLabel = document.createElement('label');
    lastNameLabel.textContent = 'Фамилия:';
    personalInfoContainer.appendChild(lastNameLabel);

    const lastNameInput = document.createElement('input');
    lastNameInput.type = 'text';
    lastNameInput.name = 'last_name';
    lastNameInput.required = true;
    personalInfoContainer.appendChild(lastNameInput);

    // Инпут для Имя
    const firstNameLabel = document.createElement('label');
    firstNameLabel.textContent = 'Имя:';
    personalInfoContainer.appendChild(firstNameLabel);

    const firstNameInput = document.createElement('input');
    firstNameInput.type = 'text';
    firstNameInput.name = 'first_name';
    firstNameInput.required = true;
    personalInfoContainer.appendChild(firstNameInput);

    // Инпут для Отчество
    const middleNameLabel = document.createElement('label');
    middleNameLabel.textContent = 'Отчество:';
    personalInfoContainer.appendChild(middleNameLabel);

    const middleNameInput = document.createElement('input');
    middleNameInput.type = 'text';
    middleNameInput.name = 'middle_name';
    middleNameInput.required = true;
    personalInfoContainer.appendChild(middleNameInput);

    // Инпут для Дата рождения
    const birthDateLabel = document.createElement('label');
    birthDateLabel.textContent = 'Дата рождения:';
    personalInfoContainer.appendChild(birthDateLabel);

    const birthDateInput = document.createElement('input');
    birthDateInput.type = 'date';
    birthDateInput.name = 'birth_date';
    birthDateInput.required = true;
    personalInfoContainer.appendChild(birthDateInput);

    // Инпут для Телефон
    const phoneLabel = document.createElement('label');
    phoneLabel.textContent = 'Телефон:';
    personalInfoContainer.appendChild(phoneLabel);

    const phoneInput = document.createElement('input');
    phoneInput.type = 'tel';
    phoneInput.name = 'phone';
    phoneInput.required = true;
    CreatePhoneMask(phoneInput);
    personalInfoContainer.appendChild(phoneInput);

    // Добавление контейнера personalInfo в форму
    form.appendChild(personalInfoContainer);

    // Инпут для Скидка
    const discountLabel = document.createElement('label');
    discountLabel.textContent = 'Скидка в процентах:';
    clientInfoContainer.appendChild(discountLabel);

    const discountInput = document.createElement('input');
    discountInput.type = 'number';
    discountInput.name = 'discount';
    discountInput.required = true;
    clientInfoContainer.appendChild(discountInput);

    // Добавление контейнера clientInfo в форму
    form.appendChild(clientInfoContainer);

    // Добавление формы в модальное окно
    modal.appendChild(form);

    // Создание контейнера для кнопок
    const buttonContainer = document.createElement('div');
    buttonContainer.classList.add('container_buttons');

    // Создание кнопки ОК
    const okButton = document.createElement('button');
    okButton.textContent = 'ОК';
    okButton.className = 'greenButton';
    okButton.addEventListener('click', () => SubmitClientCreateClick(modal, clientsTable));
    buttonContainer.appendChild(okButton);

    // Создание кнопки закрытия
    const closeButton = document.createElement('button');
    closeButton.textContent = 'Закрыть';
    closeButton.className = 'redButton';
    closeButton.addEventListener('click', () => CloseModal(modal));
    buttonContainer.appendChild(closeButton);

    // Добавление контейнера с кнопками в модальное окно
    modal.appendChild(buttonContainer);

    // Добавление модального окна в body
    document.body.appendChild(modal);
}

function SubmitClientCreateClick(modal, clientsTable) {
    const inputs = modal.querySelectorAll('input');

    const formData = {};

    inputs.forEach(input => {
        formData[input.name] = input.value;
    });

    fetch('/createClient', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })
    .then(client => {
        alert('Клиент успешно создан.');

        // Используем ParseJsonToTable для обновления таблицы
        ParseJsonToTable([client], clientsTable); // Предполагаем, что сервер возвращает массив с одним клиентом

    })
    .catch((error) => {
        console.error('Error:', error);
        alert('Error: ' + error.message);
    });

    CloseModal(modal);
}

function RemoveClient(clientTable) {
    // Находим строку с классом 'selected'
    const selectedRow = clientTable.querySelector('tr.selected');

    // Убедимся, что такая строка существует
    if (!selectedRow) {
        alert('Не выбрана строка для удаления.');
        return;
    }

    // Получаем содержимое первой ячейки этой строки
    const clientId = selectedRow.cells[0].textContent;

    // Подтверждение удаления
    const confirmation = confirm(`Вы действительно хотите удалить клиента с ID ${clientId}?`);
    if (!confirmation) {
        return;
    }

    // Формируем данные для отправки
    const formData = {
        ид_клиента: clientId
    };

    // Отправляем fetch запрос на удаление клиента
    fetch('/deleteClient', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
    })
    .then(response => {
        // Проверяем статус ответа
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        alert('Клиент успешно удален.');
        clientTable.deleteRow(selectedRow.rowIndex);
    })
    .catch((error) => {
        alert(error.message);
    });
}

// Сотрудники

function ModalCreateEmployee(employeeTable) {

    // Создаем модальное окно
    const modal = document.createElement('div');
    modal.classList.add('modal');
    modal.id = 'modalCreateEmployee';

    // Вызов функции для создания оверлея
    CreateOverlay(modal);

    // Создание заголовка модального окна
    const title = document.createElement('h1');
    title.textContent = 'Создание сотрудника';
    modal.appendChild(title);

    // Создание формы для инпутов
    const form = document.createElement('form');

    // Создание контейнеров для различных частей формы
    const personalInfoContainer = document.createElement('div');
    personalInfoContainer.classList.add('personalInfo');

    const employeeInfoContainer = document.createElement('div');
    employeeInfoContainer.classList.add('employeeInfo');

    // Инпут для Фамилия
    const lastNameLabel = document.createElement('label');
    lastNameLabel.textContent = 'Фамилия:';
    personalInfoContainer.appendChild(lastNameLabel);

    const lastNameInput = document.createElement('input');
    lastNameInput.type = 'text';
    lastNameInput.name = 'last_name';
    lastNameInput.required = true;
    personalInfoContainer.appendChild(lastNameInput);

    // Инпут для Имя
    const firstNameLabel = document.createElement('label');
    firstNameLabel.textContent = 'Имя:';
    personalInfoContainer.appendChild(firstNameLabel);

    const firstNameInput = document.createElement('input');
    firstNameInput.type = 'text';
    firstNameInput.name = 'first_name';
    firstNameInput.required = true;
    personalInfoContainer.appendChild(firstNameInput);

    // Инпут для Отчество
    const middleNameLabel = document.createElement('label');
    middleNameLabel.textContent = 'Отчество:';
    personalInfoContainer.appendChild(middleNameLabel);

    const middleNameInput = document.createElement('input');
    middleNameInput.type = 'text';
    middleNameInput.name = 'middle_name';
    middleNameInput.required = true;
    personalInfoContainer.appendChild(middleNameInput);

    // Инпут для Дата рождения
    const birthDateLabel = document.createElement('label');
    birthDateLabel.textContent = 'Дата рождения:';
    personalInfoContainer.appendChild(birthDateLabel);

    const birthDateInput = document.createElement('input');
    birthDateInput.type = 'date';
    birthDateInput.name = 'birth_date';
    birthDateInput.required = true;
    personalInfoContainer.appendChild(birthDateInput);

    // Инпут для Телефон
    const phoneLabel = document.createElement('label');
    phoneLabel.textContent = 'Телефон:';
    personalInfoContainer.appendChild(phoneLabel);

    const phoneInput = document.createElement('input');
    phoneInput.type = 'tel';
    phoneInput.name = 'phone';
    phoneInput.required = true;
    CreatePhoneMask(phoneInput);
    personalInfoContainer.appendChild(phoneInput);

    // Инпут для Серий паспорта
    const passportSerialLabel = document.createElement('label');
    passportSerialLabel.textContent = 'Серия паспорта:';
    employeeInfoContainer.appendChild(passportSerialLabel);

    const passportSerialInput = document.createElement('input');
    passportSerialInput.type = 'text';
    passportSerialInput.name = 'passport_serial';
    passportSerialInput.required = true;
    employeeInfoContainer.appendChild(passportSerialInput);

    // Инпут для Номер паспорта
    const passportNumberLabel = document.createElement('label');
    passportNumberLabel.textContent = 'Номер паспорта:';
    employeeInfoContainer.appendChild(passportNumberLabel);

    const passportNumberInput = document.createElement('input');
    passportNumberInput.type = 'text';
    passportNumberInput.name = 'passport_number';
    passportNumberInput.required = true;
    employeeInfoContainer.appendChild(passportNumberInput);

    // Добавление контейнера personalInfo в форму
    form.appendChild(personalInfoContainer);

    // Поле для Должность
    const positionLabel = document.createElement('label');
    positionLabel.textContent = 'Должность:';
    employeeInfoContainer.appendChild(positionLabel);

    const positionSelect = document.createElement('select');
    positionSelect.name = 'position';
    const positions = [
        { name: 'Кассир', id: 8 },
        { name: 'Менеджер', id: 7 },
        { name: 'Администратор', id: 6 }
    ];
    positions.forEach(position => {
        const option = document.createElement('option');
        option.value = position.id;
        option.textContent = position.name;
        positionSelect.appendChild(option);
    });
    employeeInfoContainer.appendChild(positionSelect);

    // Инпут для Персональный код
    const personalCodeLabel = document.createElement('label');
    personalCodeLabel.textContent = 'Персональный код:';
    employeeInfoContainer.appendChild(personalCodeLabel);

    const personalCodeInput = document.createElement('input');
    personalCodeInput.type = 'text';
    personalCodeInput.name = 'personal_code';
    personalCodeInput.required = true;
    employeeInfoContainer.appendChild(personalCodeInput);

    // Добавление контейнера employeeInfo в форму
    form.appendChild(employeeInfoContainer);

    // Добавление формы в модальное окно
    modal.appendChild(form);

    // Создание контейнера для кнопок
    const buttonContainer = document.createElement('div');
    buttonContainer.classList.add('container_buttons');

    // Создание кнопки ОК
    const okButton = document.createElement('button');
    okButton.textContent = 'ОК';
    okButton.className = 'greenButton';
    okButton.addEventListener('click', () => SubmitEmployeeCreateClick(modal, employeeTable));
    buttonContainer.appendChild(okButton);

    // Создание кнопки закрытия
    const closeButton = document.createElement('button');
    closeButton.textContent = 'Закрыть';
    closeButton.className = 'redButton';
    closeButton.addEventListener('click', () => CloseModal(modal));
    buttonContainer.appendChild(closeButton);

    // Добавление контейнера с кнопками в модальное окно
    modal.appendChild(buttonContainer);

    // Добавление модального окна в body
    document.body.appendChild(modal);

    // Устанавливаем значение по умолчанию
    positionSelect.value = 8;
}

function SubmitEmployeeCreateClick(modal, employeeTable) {
    const inputs = modal.querySelectorAll('input');
    const selects = modal.querySelectorAll('select');

    const formData = {};

    inputs.forEach(input => {
        formData[input.name] = input.value;
    });

    selects.forEach(select => {
        formData[select.name] = select.value;
    });

    fetch('/createEmployee', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })
    .then(employee => {
        alert('Сотрудник успешно создан.');

        ParseJsonToTable([employee], employeeTable);
    })
    .catch((error) => {
        console.error('Error:', error);
        alert('Error: ' + error.message);
    });

    CloseModal(modal);
}

function RemoveEmployee(employeeTable) {
    // Находим строку с классом 'selected'
    const selectedRow = employeeTable.querySelector('tr.selected');

    // Убедимся, что такая строка существует
    if (!selectedRow) {
        alert('Не выбрана строка для удаления.');
        return;
    }

    // Получаем содержимое первой ячейки этой строки
    const employeeId = selectedRow.cells[0].textContent;

    // Подтверждение удаления
    const confirmation = confirm(`Вы действительно хотите удалить сотрудника с ID ${employeeId}?`);
    if (!confirmation) {
        return;
    }

    // Формируем данные для отправки
    const formData = {
        ид_сотрудника: employeeId
    };

    // Отправляем fetch запрос на удаление сотрудника
    fetch('/deleteEmployee', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
    })
    .then(response => {
        // Проверяем статус ответа
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        alert('Сотрудник успешно удален.');
        employeeTable.deleteRow(selectedRow.rowIndex);
    })
    .catch((error) => {
        alert(error.message);
    });
}

// Отчеты

function CreateReportSupplies(container) {
    var startDateInput = container.querySelector('#начальная_дата_поставки');
    var endDateInput = container.querySelector('#конечная_дата_поставки');

    var startDate = startDateInput.value;
    var endDate = endDateInput.value;

    var jsonData = {
        начальная_дата: startDate,
        конечная_дата: endDate
    };

    fetch('/createReportSupplies', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(jsonData)
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })
    .then(data => {
        alert('Отчет успешно создан.');

        // Преобразуем каждую строку из массива в объект JSON
        var dataArray = data.map(item => JSON.parse(item));

        // Создаем Excel документ из полученных данных
        var wb = XLSX.utils.book_new();
        wb.Props = {
            Title: "Отчет",
            Subject: "Отчет о расходах",
            Author: "Аптечная система",
            CreatedDate: new Date()
        };

        // Определяем заголовки для листа Excel
        var ws_data = [
            ["ИД Поставщика", "Название Поставщика", "Оптовая Цена", "Название Каталога", "Производитель", "Сумма Расходов"]
        ];

        // Добавляем данные в лист Excel
        dataArray.forEach(item => {
            ws_data.push([
                item.ид_поставщика,
                item.название_поставщика,
                item.оптовая_цена,
                item.название_каталога,
                item.производитель,
                item.сумма_расходов
            ]);
        });

        // Вычисляем итоговую сумму по столбцу "Сумма Расходов"
        var totalSum = dataArray.reduce((sum, item) => sum + item.сумма_расходов, 0);

        // Добавляем строку с итоговой суммой
        ws_data.push(["", "", "", "", "Итого", totalSum]);

        // Преобразуем данные в лист Excel
        var ws = XLSX.utils.aoa_to_sheet(ws_data);

        XLSX.utils.book_append_sheet(wb, ws, "Расходы");

        // Записываем Excel файл с использованием xlsx-style
        XLSX.writeFile(wb, 'Отчет_расходов.xlsx');
    })
    .catch(error => {
        alert(error.message);
    });
}

function CreateReportSales(container) {
    var startDateInput = container.querySelector('#начальная_дата_продажи');
    var endDateInput = container.querySelector('#конечная_дата_продажи');

    var startDate = startDateInput.value;
    var endDate = endDateInput.value;

    var jsonData = {
        начальная_дата: startDate,
        конечная_дата: endDate
    };

    fetch('/createReportSales', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(jsonData)
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })
    .then(data => {
        alert('Отчет успешно создан.');

        // Преобразуем каждую строку из массива в объект JSON
        var dataArray = data.map(item => JSON.parse(item));

        // Создаем Excel документ из полученных данных
        var wb = XLSX.utils.book_new();
        wb.Props = {
            Title: "Отчет",
            Subject: "Отчет о продажах",
            Author: "Аптечная система",
            CreatedDate: new Date()
        };

        // Определяем заголовки для листа Excel
        var ws_data = [
            ["Время Продажи", "Сумма Продажи", "ИД Персоны", "Фамилия", "Имя", "Отчество", "Название", "Производитель", "Дозировка", "По_Рецепту", "ИД Лекарства"]
        ];

        // Добавляем данные в лист Excel
        dataArray.forEach(item => {
            ws_data.push([
                item.время,
                item.сумма,
                item.ид_персоны,
                item.фамилия,
                item.имя,
                item.отчество,
                item.название,
                item.производитель,
                item.дозировка,
                item.по_рецепту,
                item.ид_лекарства
            ]);
        });

        // Определить индекс последней строки
        const lastRowIndex = ws_data.length;

        // Добавляем строку с итоговой суммой
        const totalFormula = `SUM(B2:B${lastRowIndex})`;
        ws_data.push(["", {f: totalFormula}, "", "", "", "", "", "", "", "", ""]);

        // Преобразуем данные в лист Excel
        var ws = XLSX.utils.aoa_to_sheet(ws_data);

        XLSX.utils.book_append_sheet(wb, ws, "Продажи");

        // Записываем Excel файл с использованием xlsx-style
        XLSX.writeFile(wb, 'Отчет_продаж.xlsx');
    })
    .catch(error => {
        alert(error.message);
    });
}

// Утилити

function GenerateRandomRows(table, rowCount) {
    return new Promise((resolve) => {
        const tbody = table.querySelector('tbody');
        const columnCount = table.querySelector('thead tr').cells.length;

        for (let i = 0; i < rowCount; i++) {
            const newRow = document.createElement('tr');

            // Создаем ячейки в строке на основе количества столбцов в таблице
            for (let j = 0; j < columnCount; j++) {
                const newCell = document.createElement('td');

                // Генерируем случайное число из 5 цифр
                const randomFiveDigitNumber = Math.floor(10000 + Math.random() * 90000);
                newCell.textContent = randomFiveDigitNumber;

                newRow.appendChild(newCell);
            }

            tbody.appendChild(newRow);
        }
        resolve();
    });
}

function AddCheckboxColumn(table) {
    const thead = table.querySelector('thead tr');
    let checkboxColumnIndex = -1;
    let checkboxColumn = thead.querySelector('th[name="checkBoxColumn"]');

    // Если колонка не существует, создаем новую
    if (!checkboxColumn) {
        checkboxColumn = document.createElement('th');
        checkboxColumn.setAttribute('name', 'checkBoxColumn');
        thead.appendChild(checkboxColumn);
        checkboxColumnIndex = thead.children.length - 1;
    } else {
        checkboxColumnIndex = Array.from(thead.children).indexOf(checkboxColumn);
    }

    // Добавляем или обновляем чекбоксы в каждой строке таблицы
    const tbody = table.querySelector('tbody');
    const rows = tbody.querySelectorAll('tr');

    rows.forEach(row => {
        // Удаляем содержимое существующей ячейки чекбокса, если оно есть
        const existingCheckboxCell = row.children[checkboxColumnIndex];
        if (existingCheckboxCell) {
            existingCheckboxCell.remove();
        }

        // Создаем новую ячейку с чекбоксом
        const newTd = document.createElement('td');
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        newTd.appendChild(checkbox);

        // Вставляем новую ячейку на правильное место
        if (checkboxColumnIndex >= row.children.length) {
            row.appendChild(newTd);
        } else {
            row.insertBefore(newTd, row.children[checkboxColumnIndex]);
        }
    });
}

function InputTodayDate(input) {
    // Проверяем, что переданный элемент является элементом ввода и что его тип - date
    if (input && input.tagName === 'INPUT' && input.type === 'date') {
        // Получаем сегодняшнюю дату
        const today = new Date();

        // Форматируем дату в строку YYYY-MM-DD
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');  // Месяца считаются от 0 до 11
        const day = String(today.getDate()).padStart(2, '0');

        const formattedDate = `${year}-${month}-${day}`;

        // Устанавливаем сегодняшнюю дату в input
        input.value = formattedDate;
    } else {
        console.error('Передан некорректный элемент ввода или его тип не является date.');
    }
}

function InputTodayTimestamp(input) {

    const now = new Date();

    // Форматируем дату и время в строку YYYY-MM-DD HH:MM:SS
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');

    const formattedTimestamp = `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;

    // Устанавливаем текущий timestamp в input
    input.value = formattedTimestamp;
}

function StartTimer(input) {
    // Инициализация таймера
    let startTime = Date.now();

    function padZero(number) {
        return number < 10 ? '0' + number : number;
    }

    function updateTimer() {
        const elapsedTime = Date.now() - startTime;
        const days = Math.floor(elapsedTime / (1000 * 60 * 60 * 24));
        const hours = Math.floor((elapsedTime % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((elapsedTime % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((elapsedTime % (1000 * 60)) / 1000);

        const formattedTime = `${padZero(days)}:${padZero(hours)}:${padZero(minutes)}:${padZero(seconds)}`;
        input.value = formattedTime;
    }

    // Обновление каждую секунду
    setInterval(updateTimer, 1000);
}

function CalculateTime(startTime, timePassed) {
    // Используем moment для парсинга startTime в формате UTC
    let startDate = moment.utc(startTime, "YYYY-MM-DD HH:mm:ss");

    // Разбиваем timePassed на отдельные составляющие
    let timeParts = timePassed.split(':');
    let days = parseInt(timeParts[0], 10);
    let hours = parseInt(timeParts[1], 10);
    let minutes = parseInt(timeParts[2], 10);
    let seconds = parseInt(timeParts[3], 10);

    // Прибавляем соответствующие значения к времени
    startDate.add(days, 'days');
    startDate.add(hours, 'hours');
    startDate.add(minutes, 'minutes');
    startDate.add(seconds, 'seconds');

    // Возвращаем результат в формате YYYY-MM-DD HH:mm:ss
    return startDate.format("YYYY-MM-DD HH:mm:ss");
}

function ParseJsonToTable(jsonData, table) {
    const headers = table.querySelectorAll('th');
    const headerMap = {};

    // Шаг 1: Примитивное мапирование хедеров таблицы
    headers.forEach(header => {
        const name = header.getAttribute('name');
        const expandedColumns = header.getAttribute('data-expanded-columns');

        if (expandedColumns) {
            headerMap[expandedColumns] = header.cellIndex; // Сохраняем индекс ячейки
        } else if (name) {
            headerMap[name] = header.cellIndex; // Сохраняем индекс ячейки
        }
    });

    // Шаг 2: Добавляем строки данных
    jsonData.forEach(dataRow => {
        const newRow = table.insertRow();

        Object.keys(headerMap).forEach(key => {
            const cell = newRow.insertCell(headerMap[key]);
            cell.textContent = dataRow[key] || '';
        });
    });
}

function AttachSelectAbility(table) {
    // Проверяем, что table действительно является элементом DOM
    if (!(table instanceof HTMLElement)) {
        throw new Error("Переданный аргумент не является элементом DOM");
    }

    // Добавляем обработчик события клика на tbody таблицы
    const tbody = table.querySelector('tbody');
    if (!tbody) {
        throw new Error("Таблица не содержит элемента tbody");
    }

    tbody.addEventListener('click', function(event) {
        // Ищем строку (tr), по которой был совершён клик
        let targetRow = event.target.closest('tr');

        // Если строки нет, выходим из функции
        if (!targetRow) return;

        // Удаляем класс selected со всех строк в tbody
        document.querySelectorAll('tbody tr').forEach(row => row.classList.remove('selected'));

        // Добавляем класс selected к строке, по которой кликнули
        targetRow.classList.add('selected');
    });
}

function GetHeaders(table) {
    let headers = [];

    let thElements = table.querySelectorAll('thead th');

    thElements.forEach(th => {
        if (th.hasAttribute('data-expanded-columns')) {
            headers.push(th.getAttribute('data-expanded-columns'));
        } else if (th.hasAttribute('name')) {
            headers.push(th.getAttribute('name'));
        }
    });

    return headers;
}

function AddRowToTable(jsonRow, table) {
    var jsonData = (typeof jsonRow === 'string') ? JSON.parse(jsonRow) : jsonRow;
    var tableBody = table.querySelector('tbody');
    var headers = table.querySelectorAll('th');
    var row = tableBody.insertRow();

    // Проходим по всем заголовкам и заполняем ячейки
    Array.from(headers).forEach(function(header) {
        var cell = row.insertCell();
        // Используем атрибут 'name' заголовка для получения значения из jsonData
        var jsonFieldName = header.getAttribute('name');
        var value = jsonData[jsonFieldName] || '';
        cell.textContent = value;

        // Проверяем наличие атрибута 'data-expanded-source'
        var expandedSource = header.getAttribute('data-expanded-source');
        if (expandedSource) {
            // Вызываем функцию GetExpandedData для этого столбца
            GetExpandedData(cell, header);
        }
    });
}

function GetExpandedData(cell, header) {
    var value = cell.textContent;

    // Установка скрытого атрибута с прочитанным значением
    cell.setAttribute('data-value', value);

    var expandedSource = header.dataset.expandedSource;
    var expandedColumns = header.dataset.expandedColumns.split(', ');
    var columnName = header.getAttribute('name');
    var expandedPrefix = header.dataset.expandedPrefix;

    var dataToSend = {
        value: value,
        columnName: columnName,
        expandedSource: expandedSource,
        expandedColumns: expandedColumns
    };

    var jsonString = JSON.stringify(dataToSend);

    fetch('/getExpandedData', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: jsonString
    })
    .then(response => response.json())
    .then(data => {
        // Создаем упорядоченный массив данных
        var orderedData = expandedColumns.map(column => data[column]);

        // Форматируем данные с префиксом
        var formattedData = FormatDataWithPrefix(orderedData, expandedPrefix);

        // Проверяем значения данных и устанавливаем цвет ячейки
        orderedData.forEach(function(item) {
            if (item === true) {
                cell.style.backgroundColor = 'green';
                cell.textContent = '';  // Удаляем textContent если закрашивается зеленым
            } else if (item === false) {
                cell.style.backgroundColor = 'red';
                cell.textContent = '';  // Удаляем textContent если закрашивается красным
            } else {
                cell.innerHTML = formattedData;
            }
        });
    })
    .catch(error => {
        console.error('Error fetching expanded data:', error);
        cell.textContent = 'Error loading data';
    });
}

function FormatDataWithPrefix(data, prefix) {
    // Если data не массив, превращаем его в массив
    if (!Array.isArray(data)) {
        data = [data];
    }

    // Используем reduce для создания строки с заменой символов * и $ на <br>
    return data.reduce((formattedString, value) => {
        // Заменяем первое вхождение * на текущее значение value
        formattedString = formattedString.replace('*', value);
        // Заменяем все вхождения $ на тег <br> для переноса строки в HTML
        return formattedString.replace(/\$/g, '<br>');
    }, prefix);
}

function UpdateTable(table) {
    var tablename = table.getAttribute('name');
    var tableBody = table.querySelector('tbody');

    while (tableBody.firstChild) {
        tableBody.removeChild(tableBody.firstChild);
    }

    // Получаем атрибуты из data-attributes и парсим их
    var attributesString = table.getAttribute('data-attributes');
    var attributes = {};

    if (attributesString) {
        attributesString.split(',').forEach(attr => {
            let [key, value] = attr.split('=');
            attributes[key.trim()] = value.trim();
        });
    }

    var requestData = {
        tablename: tablename,
        attributes: attributes
    };

    var url = '/getAllRecordsByAttribute';

    return fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestData)
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(errorBody => {
                throw new Error(errorBody.error);
            });
        }
        return response.json();
    })
    .then(result => {
        if (result.length === 0 || (result.length === 1 && result[0] === '[]')) {
            alert('Записи в данной таблице отсутсвуют');
        } else {
            result.forEach(jsonString => {
                let jsonRow = JSON.parse(jsonString);
                AddRowToTable(jsonRow, table);
            });

            SortTable(table, 0);
        }
    })
    .catch(error => {
        console.error('Fetch operation error:', error);
        alert(error.message);
    });
}

function AttachRowClick(table, onClickFunction) {
    // Получаем все строки в теле таблицы
    var rows = table.getElementsByTagName('tbody')[0].getElementsByTagName('tr');

    // Проходим по каждой строке и добавляем обработчик события
    for (var i = 0; i < rows.length; i++) {
        rows[i].addEventListener('click', function(event) {
            onClickFunction(event.currentTarget);
        });
    }
}

function AddSortingToTableHeaders(table) {
    var headers = table.getElementsByTagName("th");
    for (let i = 0; i < headers.length; i++) {
        headers[i].addEventListener("click", function() {
            SortTable(table, i);
        });
    }
}

function SortTable(table, columnIndex) {
    var rows, switching, i, x, y, shouldSwitch;
    switching = true;
    // Продолжаем цикл до тех пор, пока не будет выполнено ни одной перестановки
    while (switching) {
        switching = false;
        rows = table.getElementsByTagName("TR");
        // Проходим по всем строкам таблицы, кроме заголовка
        for (i = 1; i < (rows.length - 1); i++) {
            shouldSwitch = false;
            // Получаем сравниваемые элементы
            x = rows[i].getElementsByTagName("TD")[columnIndex];
            y = rows[i + 1].getElementsByTagName("TD")[columnIndex];
            // Проверяем, являются ли значения числами
            var xValue = isNaN(x.innerHTML) ? x.innerHTML.toLowerCase() : parseFloat(x.innerHTML);
            var yValue = isNaN(y.innerHTML) ? y.innerHTML.toLowerCase() : parseFloat(y.innerHTML);
            // Определяем, должны ли элементы поменяться местами
            if (xValue > yValue) {
                shouldSwitch = true;
                break;
            }
        }
        if (shouldSwitch) {
            // Если элементы должны поменяться местами, выполняем перестановку и помечаем, что была выполнена перестановка
            rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
            switching = true;
        }
    }
}

function CreatePhoneMask(phoneInput) {
    // Начальное значение
    phoneInput.value = '+7';

    // Функция для проверки и форматирования ввода
    function formatInput(event) {
        const inputValue = phoneInput.value;

        // Предотвращаем удаление префикса '+7'
        if (!inputValue.startsWith('+7')) {
            phoneInput.value = '+7';
        }

        // Ограничиваем длину номера до 12 символов включая '+7'
        if (inputValue.length > 12) {
            alert('Номер не может быть длиннее 11 цифр.');
            phoneInput.value = inputValue.slice(0, 12);
        }

        // Удаляем все символы, кроме цифр (но оставляем '+7')
        const rawValue = phoneInput.value.replace(/[^0-9\+]/g, '');

        if (rawValue !== phoneInput.value) {
            alert('Можно вводить только цифры.');
        }

        phoneInput.value = '+7' + rawValue.slice(2);
    }

    // Обработчик события input
    phoneInput.addEventListener('input', formatInput);

    // Обработчик события keydown для предотвращения удаления префикса
    phoneInput.addEventListener('keydown', function(event) {
        const cursorPos = phoneInput.selectionStart;

        // Запрет на внесение изменений в первые два символа
        if (cursorPos < 2 && (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft')) {
            event.preventDefault();
        }
    });
}

function HideColumns(table) {
    // Получаем все заголовки таблицы
    const headers = table.querySelectorAll('th');
    headers.forEach((header, columnIndex) => {
        // Проверяем, есть ли атрибут data-hide со значением true
        if (header.dataset.hide === 'true') {
            // Скрываем заголовок
            header.hidden = true;

            // Скрываем все ячейки в этом столбце
            table.querySelectorAll('tr').forEach(row => {
                const cells = row.querySelectorAll('td, th');
                if (cells[columnIndex]) {
                    cells[columnIndex].hidden = true;
                }
            });
        }
    });
}

function FillSearchSelectOptions(selectElement, table) {
    // Очистим selectElement перед добавлением новых option
    selectElement.innerHTML = '';

    // Получаем все хедеры таблицы
    const headers = table.querySelectorAll('thead th');

    // Проходимся по всем хедерам таблицы
    headers.forEach(header => {
        // Проверяем, что у хедера нет атрибута hidden и его textContent непустой
        if (!header.hasAttribute('hidden') && header.textContent.trim() !== '') {
            // Создаем новый элемент option и задаем ему textContent из хедера
            const option = document.createElement('option');
            option.textContent = header.textContent.trim();
            selectElement.appendChild(option);
        }
    });
}

function MakeSearch(selectElement, table, input) {
    // Получаем текстовое значение из input
    const searchValue = input.value.trim().toLowerCase();

    // Получаем выбранное значение из selectElement
    const selectedHeader = selectElement.value;

    // Получаем имя таблицы из атрибута name
    const sourceTableName = table.getAttribute('name');

    // Получаем URL для запроса
    const url = '/getAllRecords/' + encodeURIComponent(sourceTableName);

    // Параметры для запроса
    const paramsToJoin = {}; // Если нужны дополнительные параметры, добавьте их сюда

    fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(paramsToJoin)
    })
    .then(response => {
        if (!response.ok) {
            return response.json().then(error => {
                throw new Error(error.error);
            });
        }
        return response.json();
    })
    .then(records => {
        // Очищаем текущие строки таблицы, кроме заголовка
        const tbody = table.querySelector('tbody');
        tbody.innerHTML = '';

        // Получаем индекс столбца с textContent, соответствующим выбранному option
        const headers = Array.from(table.querySelectorAll('thead th'));
        const headerIndex = headers.findIndex(header => header.textContent.trim() === selectedHeader);

        // Проходим по всем записям, полученным с сервера
        records.forEach(record => {
            const cells = Object.values(record);
            const cellValue = cells[headerIndex].toLowerCase();

            // Проверяем, находится ли значение ячейки в выбранном столбце в строке
            if (cellValue.includes(searchValue)) {
                // Создаем новую строку таблицы
                const row = document.createElement('tr');
                cells.forEach(cellValue => {
                    const cell = document.createElement('td');
                    cell.textContent = cellValue;
                    row.appendChild(cell);
                });
                // Добавляем строку в таблицу
                tbody.appendChild(row);
            }
        });
    })
    .catch(error => {
        alert(error.message);
        console.error('There has been a problem with your fetch operation:', error);
    });
}