$(document).ready(function() {
    $(".tagsTable").tablesorter();
    $("#tagsTable1 tr").click(function(e) {
        var children = $(e.currentTarget).children();
        $('input[name=tagName]').val($(children[1]).children()[0].text);
        $('input[name=tagValue]').val($(children[2]).html());
        $('input[name=tagFetch]').attr('checked', $(children[3]).text() == 'true');
    });
    $("#tagsTable2 tr").click(function(e) {
        var children = $(e.currentTarget).children();
        $('input[name=tagName]').val($(children[1]).children()[0].text);
        $('input[name=tagValue]').val(0);
        $('input[name=tagFetch]').attr('checked', false);
    });
});

function fetch(tag) {
    callAndDisplayResult('/fetch/' + tag);
}

function reblog(id) {
    if (confirm("Are you sure you want to reblog this post ?")) {
        callAndDisplayResult('/reblog/' + id);
    }
}

function skip(id) {
    if (confirm("Are you sure you want to skip this post ?")) {
        callAndDisplayResult('/skip/' + id);
    }
}

function reblogNext() {
    return confirm("Are you sure you want to reblog the next post ?");
}

function callAndDisplayResult(url) {
    $.get(url, function(data) {
        displayMessage(data);
    });
}

function displayMessage(message) {
    var displayResult = function() {
        $('#messages').append('<div id="notice" class="flash">' + message + '</div>');
    };
    if ($('.flash').length == 0) {
        displayResult();
    } else {
        $('.flash').fadeOut(function() {
            $('.flash').remove();
            displayResult();
        });
    }
}
