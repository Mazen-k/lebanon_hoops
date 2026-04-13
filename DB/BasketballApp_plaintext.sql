--
-- PostgreSQL database dump
--



-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: card_instances; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.card_instances (
    card_instance_id integer NOT NULL,
    card_id integer NOT NULL,
    user_id integer NOT NULL,
    obtained_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.card_instances OWNER TO postgres;

--
-- Name: card_instances_card_instance_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.card_instances_card_instance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.card_instances_card_instance_id_seq OWNER TO postgres;

--
-- Name: card_instances_card_instance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.card_instances_card_instance_id_seq OWNED BY public.card_instances.card_instance_id;


--
-- Name: play_cards; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.play_cards (
    card_id integer NOT NULL,
    card_type character varying(30) NOT NULL,
    player_id integer NOT NULL,
    attack integer NOT NULL,
    defend integer NOT NULL,
    card_image character varying(255),
    CONSTRAINT play_cards_attack_check CHECK ((attack >= 0)),
    CONSTRAINT play_cards_defend_check CHECK ((defend >= 0))
);


ALTER TABLE public.play_cards OWNER TO postgres;

--
-- Name: play_cards_card_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.play_cards_card_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.play_cards_card_id_seq OWNER TO postgres;

--
-- Name: play_cards_card_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.play_cards_card_id_seq OWNED BY public.play_cards.card_id;


--
-- Name: players; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.players (
    player_id integer NOT NULL,
    team_id integer NOT NULL,
    jersey_number integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    nationality character varying(50),
    "position" character varying(30),
    dominant_hand character varying(10),
    dob date
);


ALTER TABLE public.players OWNER TO postgres;

--
-- Name: players_player_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.players_player_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.players_player_id_seq OWNER TO postgres;

--
-- Name: players_player_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.players_player_id_seq OWNED BY public.players.player_id;


--
-- Name: teams; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teams (
    team_id integer NOT NULL,
    team_name character varying(100) NOT NULL
);


ALTER TABLE public.teams OWNER TO postgres;

--
-- Name: teams_team_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.teams_team_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.teams_team_id_seq OWNER TO postgres;

--
-- Name: teams_team_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.teams_team_id_seq OWNED BY public.teams.team_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    phone_number character varying(20),
    favorite_team_id integer
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_user_id_seq OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: wishlist_cards; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wishlist_cards (
    wishlist_id integer NOT NULL,
    card_id integer NOT NULL,
    added_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.wishlist_cards OWNER TO postgres;

--
-- Name: wishlists; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wishlists (
    wishlist_id integer NOT NULL,
    user_id integer NOT NULL,
    msg character varying(50) DEFAULT 'Best cards Please'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.wishlists OWNER TO postgres;

--
-- Name: wishlists_wishlist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.wishlists_wishlist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.wishlists_wishlist_id_seq OWNER TO postgres;

--
-- Name: wishlists_wishlist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.wishlists_wishlist_id_seq OWNED BY public.wishlists.wishlist_id;


--
-- Name: card_instances card_instance_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.card_instances ALTER COLUMN card_instance_id SET DEFAULT nextval('public.card_instances_card_instance_id_seq'::regclass);


--
-- Name: play_cards card_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.play_cards ALTER COLUMN card_id SET DEFAULT nextval('public.play_cards_card_id_seq'::regclass);


--
-- Name: players player_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.players ALTER COLUMN player_id SET DEFAULT nextval('public.players_player_id_seq'::regclass);


--
-- Name: teams team_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teams ALTER COLUMN team_id SET DEFAULT nextval('public.teams_team_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Name: wishlists wishlist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wishlists ALTER COLUMN wishlist_id SET DEFAULT nextval('public.wishlists_wishlist_id_seq'::regclass);


--
-- Data for Name: card_instances; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.card_instances VALUES (9, 4, 1, '2026-04-11 19:27:43.472074');
INSERT INTO public.card_instances VALUES (10, 5, 1, '2026-04-11 19:27:43.472074');
INSERT INTO public.card_instances VALUES (11, 2, 1, '2026-04-11 19:27:43.472074');
INSERT INTO public.card_instances VALUES (12, 1, 1, '2026-04-11 19:27:43.472074');
INSERT INTO public.card_instances VALUES (13, 7, 1, '2026-04-11 19:28:09.592021');
INSERT INTO public.card_instances VALUES (14, 5, 1, '2026-04-11 19:28:09.592021');
INSERT INTO public.card_instances VALUES (16, 4, 1, '2026-04-11 19:28:09.592021');
INSERT INTO public.card_instances VALUES (18, 4, 1, '2026-04-11 19:41:31.974993');
INSERT INTO public.card_instances VALUES (19, 2, 1, '2026-04-11 19:41:31.974993');
INSERT INTO public.card_instances VALUES (20, 8, 1, '2026-04-11 19:41:31.974993');
INSERT INTO public.card_instances VALUES (21, 3, 1, '2026-04-11 19:42:43.843649');
INSERT INTO public.card_instances VALUES (22, 2, 1, '2026-04-11 19:42:43.843649');
INSERT INTO public.card_instances VALUES (23, 4, 1, '2026-04-11 19:42:43.843649');
INSERT INTO public.card_instances VALUES (24, 5, 1, '2026-04-11 19:42:43.843649');
INSERT INTO public.card_instances VALUES (25, 4, 1, '2026-04-11 19:45:03.230333');
INSERT INTO public.card_instances VALUES (26, 2, 1, '2026-04-11 19:45:03.230333');
INSERT INTO public.card_instances VALUES (27, 1, 1, '2026-04-11 19:45:03.230333');
INSERT INTO public.card_instances VALUES (28, 5, 1, '2026-04-11 19:45:03.230333');
INSERT INTO public.card_instances VALUES (29, 7, 1, '2026-04-11 19:46:36.107999');
INSERT INTO public.card_instances VALUES (30, 6, 1, '2026-04-11 19:46:36.107999');
INSERT INTO public.card_instances VALUES (31, 4, 1, '2026-04-11 19:46:36.107999');
INSERT INTO public.card_instances VALUES (32, 2, 1, '2026-04-11 19:46:36.107999');
INSERT INTO public.card_instances VALUES (33, 7, 1, '2026-04-11 19:49:34.587012');
INSERT INTO public.card_instances VALUES (34, 6, 1, '2026-04-11 19:49:34.587012');
INSERT INTO public.card_instances VALUES (35, 2, 1, '2026-04-11 19:49:34.587012');
INSERT INTO public.card_instances VALUES (36, 3, 1, '2026-04-11 19:49:34.587012');
INSERT INTO public.card_instances VALUES (37, 5, 1, '2026-04-11 19:50:39.797494');
INSERT INTO public.card_instances VALUES (38, 8, 1, '2026-04-11 19:50:39.797494');
INSERT INTO public.card_instances VALUES (39, 4, 1, '2026-04-11 19:50:39.797494');
INSERT INTO public.card_instances VALUES (40, 2, 1, '2026-04-11 19:50:39.797494');
INSERT INTO public.card_instances VALUES (41, 8, 1, '2026-04-11 19:51:43.301825');
INSERT INTO public.card_instances VALUES (42, 2, 1, '2026-04-11 19:51:43.301825');
INSERT INTO public.card_instances VALUES (43, 7, 1, '2026-04-11 19:51:43.301825');
INSERT INTO public.card_instances VALUES (44, 1, 1, '2026-04-11 19:51:43.301825');
INSERT INTO public.card_instances VALUES (45, 5, 1, '2026-04-11 20:32:35.100189');
INSERT INTO public.card_instances VALUES (46, 4, 1, '2026-04-11 20:32:35.100189');
INSERT INTO public.card_instances VALUES (47, 3, 1, '2026-04-11 20:32:35.100189');
INSERT INTO public.card_instances VALUES (48, 2, 1, '2026-04-11 20:32:35.100189');
INSERT INTO public.card_instances VALUES (49, 5, 1, '2026-04-11 20:32:45.884232');
INSERT INTO public.card_instances VALUES (50, 7, 1, '2026-04-11 20:32:45.884232');
INSERT INTO public.card_instances VALUES (51, 8, 1, '2026-04-11 20:32:45.884232');
INSERT INTO public.card_instances VALUES (52, 6, 1, '2026-04-11 20:32:45.884232');
INSERT INTO public.card_instances VALUES (53, 4, 1, '2026-04-11 21:02:04.754246');
INSERT INTO public.card_instances VALUES (54, 2, 1, '2026-04-11 21:02:04.754246');
INSERT INTO public.card_instances VALUES (55, 5, 1, '2026-04-11 21:02:04.754246');
INSERT INTO public.card_instances VALUES (56, 7, 1, '2026-04-11 21:02:04.754246');
INSERT INTO public.card_instances VALUES (57, 5, 1, '2026-04-11 21:03:59.102327');
INSERT INTO public.card_instances VALUES (58, 8, 1, '2026-04-11 21:03:59.102327');
INSERT INTO public.card_instances VALUES (59, 2, 1, '2026-04-11 21:03:59.102327');
INSERT INTO public.card_instances VALUES (60, 7, 1, '2026-04-11 21:03:59.102327');
INSERT INTO public.card_instances VALUES (61, 6, 1, '2026-04-11 21:18:50.649703');
INSERT INTO public.card_instances VALUES (62, 5, 1, '2026-04-11 21:18:50.649703');
INSERT INTO public.card_instances VALUES (63, 2, 1, '2026-04-11 21:18:50.649703');
INSERT INTO public.card_instances VALUES (64, 7, 1, '2026-04-11 21:18:50.649703');
INSERT INTO public.card_instances VALUES (65, 7, 1, '2026-04-11 21:20:12.205473');
INSERT INTO public.card_instances VALUES (66, 5, 1, '2026-04-11 21:20:12.205473');
INSERT INTO public.card_instances VALUES (67, 3, 1, '2026-04-11 21:20:12.205473');
INSERT INTO public.card_instances VALUES (68, 8, 1, '2026-04-11 21:20:12.205473');
INSERT INTO public.card_instances VALUES (69, 1, 1, '2026-04-11 21:25:53.828627');
INSERT INTO public.card_instances VALUES (70, 4, 1, '2026-04-11 21:25:53.828627');
INSERT INTO public.card_instances VALUES (71, 6, 1, '2026-04-11 21:25:53.828627');
INSERT INTO public.card_instances VALUES (72, 7, 1, '2026-04-11 21:25:53.828627');
INSERT INTO public.card_instances VALUES (73, 6, 2, '2026-04-11 22:18:57.678319');
INSERT INTO public.card_instances VALUES (74, 2, 2, '2026-04-11 22:18:57.678319');
INSERT INTO public.card_instances VALUES (75, 1, 2, '2026-04-11 22:18:57.678319');
INSERT INTO public.card_instances VALUES (76, 3, 2, '2026-04-11 22:18:57.678319');
INSERT INTO public.card_instances VALUES (77, 5, 2, '2026-04-11 22:20:39.081241');
INSERT INTO public.card_instances VALUES (78, 6, 2, '2026-04-11 22:20:39.081241');
INSERT INTO public.card_instances VALUES (79, 2, 2, '2026-04-11 22:20:39.081241');
INSERT INTO public.card_instances VALUES (80, 1, 2, '2026-04-11 22:20:39.081241');
INSERT INTO public.card_instances VALUES (15, 8, 2, '2026-04-11 19:28:09.592021');
INSERT INTO public.card_instances VALUES (17, 1, 2, '2026-04-11 19:41:31.974993');


--
-- Data for Name: play_cards; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.play_cards VALUES (1, 'base', 9, 91, 92, 'https://drive.google.com/uc?export=view&id=1EjZ_o2jQ8lqnwDJN_8kffAHlQiM71qL1');
INSERT INTO public.play_cards VALUES (2, 'base', 10, 90, 91, 'https://drive.google.com/uc?export=view&id=1HmWxQkYAiSK4QkWtzI1gTbtiK9eRl6aN');
INSERT INTO public.play_cards VALUES (3, 'base', 11, 90, 87, 'https://drive.google.com/uc?export=view&id=1PDsbSjSIunoKZd4dkjXStcOpvYmNtjj0');
INSERT INTO public.play_cards VALUES (4, 'base', 12, 83, 80, 'https://drive.google.com/uc?export=view&id=1u7fj6Usnv8CFXuCu5ZF0UgSs3ynWy6MP');
INSERT INTO public.play_cards VALUES (5, 'base', 13, 79, 79, 'https://drive.google.com/uc?export=view&id=15mbHtQiV_eH8yczw0CEbLHMca92mkoaB');
INSERT INTO public.play_cards VALUES (6, 'base', 14, 92, 92, 'https://drive.google.com/uc?export=view&id=1nkf953ZYaALN5xqZj4RoraQprugZFu9e');
INSERT INTO public.play_cards VALUES (7, 'base', 15, 88, 85, 'https://drive.google.com/uc?export=view&id=16NVgKMzeyfUQUAKnKZB4TQ0CK_PmF7UQ');
INSERT INTO public.play_cards VALUES (8, 'base', 16, 88, 88, 'https://drive.google.com/uc?export=view&id=1OR8MKxa5g9_b6XJhCE4aIi64GvFeMS_B');


--
-- Data for Name: players; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.players VALUES (9, 1, 7, 'Karim', 'Zeinoun', 'Lebanese', 'SG', 'Right', '1988-06-01');
INSERT INTO public.players VALUES (10, 1, 10, 'Ali', 'Mansour', 'Lebanese', 'PG', 'Right', '1990-03-15');
INSERT INTO public.players VALUES (11, 1, 5, 'Amir', 'Saoud', 'Lebanese', 'SG', 'Right', '1991-05-19');
INSERT INTO public.players VALUES (12, 1, 22, 'Youssef', 'Ghantous', 'Lebanese', 'PG', 'Right', '1999-01-10');
INSERT INTO public.players VALUES (13, 1, 13, 'Omar', 'Soubra', 'Lebanese', 'PG', 'Right', '2000-08-12');
INSERT INTO public.players VALUES (14, 1, 4, 'Hayk', 'Gyokachyan', 'Lebanese', 'PF', 'Right', '1990-01-30');
INSERT INTO public.players VALUES (15, 1, 14, 'Bilal', 'Tabara', 'Lebanese', 'SF', 'Right', '1996-02-20');
INSERT INTO public.players VALUES (16, 1, 1, 'Ismail', 'Ahmad', 'Lebanese', 'C', 'Right', '1976-09-02');


--
-- Data for Name: teams; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.teams VALUES (1, 'Riyadi');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.users VALUES (1, 'jamal', 'jamal.elkassar@gmail.com', '$2a$10$YpmIB3Qfa2JYm9VeSGhLq.VoB/Wtlk320fi2QLgSfitGg.Idn5WJO', '78809138', 1);
INSERT INTO public.users VALUES (2, 'mazen', 'mazen@gmail.com', '$2a$10$rAgYbLWpCiII0VzCywoF3OsHlt1tU7yonZc/qR3trPiHDJs5BqD3G', '80123123', 1);


--
-- Data for Name: wishlist_cards; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.wishlist_cards VALUES (6, 4, '2026-04-11 22:26:47.185795');
INSERT INTO public.wishlist_cards VALUES (6, 7, '2026-04-11 22:26:47.185795');
INSERT INTO public.wishlist_cards VALUES (6, 8, '2026-04-11 22:26:47.185795');


--
-- Data for Name: wishlists; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.wishlists VALUES (1, 1, 'Best cards Please', '2026-04-11 22:13:37.120937');
INSERT INTO public.wishlists VALUES (6, 2, 'Best cards Please', '2026-04-11 22:26:39.916748');


--
-- Name: card_instances_card_instance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.card_instances_card_instance_id_seq', 80, true);


--
-- Name: play_cards_card_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.play_cards_card_id_seq', 8, true);


--
-- Name: players_player_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.players_player_id_seq', 16, true);


--
-- Name: teams_team_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.teams_team_id_seq', 1, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 2, true);


--
-- Name: wishlists_wishlist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.wishlists_wishlist_id_seq', 9, true);


--
-- Name: card_instances card_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.card_instances
    ADD CONSTRAINT card_instances_pkey PRIMARY KEY (card_instance_id);


--
-- Name: play_cards play_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.play_cards
    ADD CONSTRAINT play_cards_pkey PRIMARY KEY (card_id);


--
-- Name: players players_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.players
    ADD CONSTRAINT players_pkey PRIMARY KEY (player_id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (team_id);


--
-- Name: players uq_team_jersey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.players
    ADD CONSTRAINT uq_team_jersey UNIQUE (team_id, jersey_number);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: wishlist_cards wishlist_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wishlist_cards
    ADD CONSTRAINT wishlist_cards_pkey PRIMARY KEY (wishlist_id, card_id);


--
-- Name: wishlists wishlists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wishlists
    ADD CONSTRAINT wishlists_pkey PRIMARY KEY (wishlist_id);


--
-- Name: wishlists wishlists_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wishlists
    ADD CONSTRAINT wishlists_user_id_key UNIQUE (user_id);


--
-- Name: play_cards fk_card_player; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.play_cards
    ADD CONSTRAINT fk_card_player FOREIGN KEY (player_id) REFERENCES public.players(player_id) ON DELETE CASCADE;


--
-- Name: card_instances fk_instance_card; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.card_instances
    ADD CONSTRAINT fk_instance_card FOREIGN KEY (card_id) REFERENCES public.play_cards(card_id) ON DELETE CASCADE;


--
-- Name: card_instances fk_instance_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.card_instances
    ADD CONSTRAINT fk_instance_user FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: players fk_player_team; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.players
    ADD CONSTRAINT fk_player_team FOREIGN KEY (team_id) REFERENCES public.teams(team_id) ON DELETE CASCADE;


--
-- Name: users fk_user_favorite_team; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_user_favorite_team FOREIGN KEY (favorite_team_id) REFERENCES public.teams(team_id) ON DELETE SET NULL;


--
-- Name: wishlist_cards fk_wishlist_cards_card; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wishlist_cards
    ADD CONSTRAINT fk_wishlist_cards_card FOREIGN KEY (card_id) REFERENCES public.play_cards(card_id) ON DELETE CASCADE;


--
-- Name: wishlist_cards fk_wishlist_cards_wishlist; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wishlist_cards
    ADD CONSTRAINT fk_wishlist_cards_wishlist FOREIGN KEY (wishlist_id) REFERENCES public.wishlists(wishlist_id) ON DELETE CASCADE;


--
-- Name: wishlists fk_wishlist_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wishlists
    ADD CONSTRAINT fk_wishlist_user FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--



