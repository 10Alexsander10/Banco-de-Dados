--Exercicio
--01
CREATE TABLE FORNECEDOR(
	COD_FORNECEDOR SERIAL PRIMARY KEY,
	NOME_FORNECEDOR VARCHAR(50),
	ENDERECO_FORNECEDOR VARCHAR(50)
);

CREATE TABLE TITULO(
	COD_TITULO SERIAL PRIMARY KEY,
	DESCRICAO VARCHAR(50)
);


CREATE TABLE LIVRO(
	COD_LIVRO SERIAL PRIMARY KEY,
	COD_TITULO SERIAL REFERENCES TITULO(COD_TITULO),
	QUANT_ESTOQUE INT,
	VALOR_UNITARIO FLOAT
);

CREATE TABLE PEDIDO(
	COD_PEDIDO SERIAL PRIMARY KEY,
	COD_FORNECEDOR SERIAL REFERENCES FORNECEDOR(COD_FORNECEDOR),
	DATA_PEDIDO DATE,
	VALOR_TOTAL_PEDIDO FLOAT,
	QUANT_ITENS_PEDIDOS INT
);

CREATE TABLE ITEM_PEDIDO(
	COD_LIVRO SERIAL REFERENCES LIVRO(COD_LIVRO),
	COD_PEDIDO SERIAL REFERENCES PEDIDO(COD_PEDIDO),
	QUANTIDADE_ITEM INT,
	VALOR_TOTAL_ITEM FLOAT
);

-- 02
CREATE VIEW VALOR_TOTAL_FORNECEDOR_FEVEREIRO_2017 AS
SELECT NOME_FORNECEDOR, SUM(VALOR_TOTAL_PEDIDO) FROM PEDIDO NATURAL JOIN FORNECEDOR 
WHERE DATA_PEDIDO BETWEEN '2017-02-01' AND '2017-02-28' 
GROUP BY NOME_FORNECEDOR

-- A)
SELECT NOME_FORNECEDOR FROM VALOR_TOTAL_FORNECEDOR_FEVEREIRO_2017 
WHERE SUM > 50;

--B)
SELECT NOME_FORNECEDOR FROM VALOR_TOTAL_FORNECEDOR_FEVEREIRO_2017 
ORDER BY SUM DESC
LIMIT 1;

--C)
SELECT NOME_FORNECEDOR FROM VALOR_TOTAL_FORNECEDOR_FEVEREIRO_2017 WHERE 
SUM IN(SELECT MAX(SUM) FROM VALOR_TOTAL_FORNECEDOR_FEVEREIRO_2017);

--3)

--A)
CREATE FUNCTION VALIDA_PEDIDO() RETURNS trigger AS $VALIDA_PEDIDO_GATILHO$
BEGIN
	IF NEW.COD_PEDIDO IS NULL THEN
		RAISE EXCEPTION 'CODIGO_PEDIDO não pode ser nulo';
	END IF;

	IF NEW.COD_FORNECEDOR NOT IN (SELECT COD_FORNECEDOR FROM FORNECEDOR) THEN
		RAISE EXCEPTION 'O FORNECEDOR NÃO EXISTE';
	END IF;

	IF NEW.DATA_PEDIDO IS NULL THEN
		RAISE EXCEPTION 'A DATA NÃO PODE SER NULA';
	END IF;
	IF NEW.VALOR_TOTAL_PEDIDO < 0 OR NEW.VALOR_TOTAL_PEDIDO IS NULL THEN
		RAISE EXCEPTION 'O VALOR É INVÁLIDO';
	END IF;

RETURN NEW;
END;
$VALIDA_PEDIDO_GATILHO$ LANGUAGE plpgsql;

CREATE TRIGGER VALIDA_PEDIDO_GATILHO BEFORE INSERT OR UPDATE ON
PEDIDO FOR EACH ROW
EXECUTE PROCEDURE VALIDA_PEDIDO();


CREATE FUNCTION VALIDA_ITEM_PEDIDO() RETURNS trigger AS $VALIDA_ITEM_PEDIDO_GATILHO$
BEGIN
	IF NEW.COD_LIVRO NOT IN (SELECT COD_LIVRO FROM LIVRO) THEN
		RAISE EXCEPTION 'O LIVRO NÃO EXISTE';
	END IF;
	
	IF NEW.COD_PEDIDO NOT IN (SELECT COD_PEDIDO FROM PEDIDO) THEN
		RAISE EXCEPTION 'O PEDIDO NÃO EXISTE';
	END IF;

	IF NEW.QUANTIDADE_ITEM < 0 OR NEW.QUANTIDADE_ITEM IS NULL THEN
		RAISE EXCEPTION 'QUANTIDADE INVÁLIDA';
	END IF;
	
	IF NEW.VALOR_TOTAL_ITEM < 0 OR NEW.VALOR_TOTAL_ITEM IS NULL THEN
		RAISE EXCEPTION 'O VALOR_TOTAL_ITEM É INVÁLID0';
	END IF;

RETURN NEW;
END;
$VALIDA_ITEM_PEDIDO_GATILHO$ LANGUAGE plpgsql;

CREATE TRIGGER VALIDA_ITEM_PEDIDO_GATILHO BEFORE INSERT OR UPDATE ON
ITEM_PEDIDO FOR EACH ROW
EXECUTE PROCEDURE VALIDA_ITEM_PEDIDO();

--B) by Daniels

create function constraint_livro() returns trigger as $constraint_livro$ 
	begin
		-- check negative estoque
		if new.quant_estoque < 0 then
			raise exception 'quant_estoque is negative';
		-- check quant_estoque less than 10
		elsif new.quant_estoque <= 10 then
				raise info 'quant_estoque is about to run out. Pay attention to it.';
		end if; 
		return new;
	end;
$constraint_livro$ LANGUAGE plpgsql; 

create trigger trig_ins_livro before insert on livro 
for each row execute procedure constraint_livro();

create trigger trig_up_livro before update on livro 
for each row execute procedure constraint_livro();

insert into titulo (descr_titulo) values ('A volta dos que nao vieram'); 
select * from titulo;

insert into livro (cod_titulo, quant_estoque, valor_unitario) values (1, -9, 10.5);

--C) by Daniels

create function constraint_gerencia_item() returns trigger as $constraint_gerencia_item$ 
	begin
		-- IF ADD
		if (tg_op = 'insert') then
			update livro set livro.quant_estoque = livro.quant_estoque - new.quantidade_item where new.cod_livro = livro.cod_livro;
			update pedido set pedido.quant_itens_pedidos = pedido.quant_itens_pedidos + new.quantidade_item, 
			pedido.valor_total_pedido = (pedido.valor_total_pedido + new.valor_total_item) where new.cod_pedido = pedido.cod_pedido; 
		end if;
		-- IF DELETE
		if (tg_op = 'delete') then
			update livro set livro.quant_estoque = livro.quant_estoque + old.quantidade_item where old.cod_livro = livro.cod_livro;
			update pedido set pedido.quant_itens_pedidos = pedido.quant_itens_pedidos - old.quantidade_item, 
			pedido.valor_total_pedido = (pedido.valor_total_pedido - old.valor_total_item) where old.cod_pedido = pedido.cod_pedido;
		end if;
		-- IF UPDATE
		if (tg_op = 'update') then
			update livro set livro.quant_estoque = (livro.quant_estoque + old.quantidade_item - new.quantidade_item) where new.cod_livro = livro.cod_livro;
			update pedido set pedido.valor_total_pedido = (pedido.valor_total_pedido - old.valor_total_item + new.valor_total_item),
			pedido.quant_itens_pedidos = (pedido.quant_itens_pedidos - old.quantidade_item + new.quantidade_item) where old.cod_pedido = pedido.cod_pedido;
		end if;
		return new;
	end;
$constraint_gerencia_item$ LANGUAGE plpgsql; 

--D) by Pablo

CREATE FUNCTION salva_controle() RETURNS TRIGGER AS $$
BEGIN

	IF (TG_OP = 'UPDATE') THEN
		INSERT INTO controla_alteracao VALUES(TG_OP, NOW(), CURRENT_USER, OLD.cod_titulo,OLD.qtd,NEW.cod_titulo,NEW.qtd); 
	END IF;

	IF (TG_OP = 'DELETE') THEN
		INSERT INTO controla_alteracao VALUES(TG_OP, NOW(), CURRENT_USER, OLD.cod_titulo,OLD.qtd,NULL,NULL); 
	END IF;

	RETURN OLD;
END

CREATE TRIGGER salva_trigger

CREATE TABLE controla_alteracao (
operacao VARCHAR(20),
data_hora TIMESTAMP,
usuario VARCHAR(20),
cod_titulo_antigo INT,
qtd_antiga INT,
cod_titulo_novo INT,
qtd_novo INT);
