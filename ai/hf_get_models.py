import os
import asyncio
import aiohttp
from datetime import datetime, timedelta


async def fetch_models(session, url, headers, params):
    async with session.get(url, headers=headers, params=params) as response:
        if response.status != 200:
            print(f"Error: {response.status}")
            return None, None
        data = await response.json()

        next_cursor = None
        if "Link" in response.headers:
            links = response.headers["Link"].split(",")
            for link in links:
                if 'rel="next"' in link:
                    next_cursor = link.split("cursor=")[1].split(">")[0]
                    break

        return data, next_cursor


async def get_models(
    token,
    last_days,
    batch,
    max_results,
    min_downloads,
    min_likes,
    concurrency,
    licenses,
    exclude_words,
):
    base_url = "https://huggingface.co/api/models"
    headers = {"Authorization": f"Bearer {token}"}
    params = {
        "pipeline_tag": "text-generation",
        "license": licenses,
        "sort": "lastModified",
        "direction": "-1",
        "limit": batch,
    }

    all_models = []
    unique_models = set()
    cutoff_date = datetime.now() - timedelta(days=last_days)
    total_processed = 0

    print("Search Parameters:")
    print(f"- Last days: {last_days}")
    print(f"- Batch size: {batch}")
    print(f"- Max results: {max_results}")
    print(f"- Min downloads: {min_downloads}")
    print(f"- Min likes: {min_likes}")
    print(f"- Concurrency: {concurrency}")
    print(f"- Licenses: {', '.join(licenses)}")
    print(f"- Excluded words: {', '.join(exclude_words)}")
    print("\nStarting search...")

    async with aiohttp.ClientSession() as session:
        tasks = [
            asyncio.create_task(fetch_models(session, base_url, headers, params))
            for _ in range(concurrency)
        ]
        while tasks:
            done, pending = await asyncio.wait(
                tasks, return_when=asyncio.FIRST_COMPLETED
            )
            tasks = list(pending)

            for task in done:
                try:
                    models, next_cursor = await task
                    if models is None:
                        continue

                    for model in models:
                        total_processed += 1
                        last_modified = datetime.strptime(
                            model["lastModified"], "%Y-%m-%dT%H:%M:%S.%fZ"
                        )
                        if last_modified < cutoff_date:
                            print(
                                f"\nReached models older than {last_days} days. Stopping search."
                            )
                            return all_models

                        downloads = model.get("downloads", 0)
                        likes = model.get("likes", 0)
                        if downloads < min_downloads or likes < min_likes:
                            continue

                        model_id = model["modelId"]

                        if model_id in unique_models or any(
                            word.lower() in model_id.lower() for word in exclude_words
                        ):
                            continue

                        unique_models.add(model_id)

                        license = next(
                            (
                                tag.split(":")[1]
                                for tag in model.get("tags", [])
                                if tag.startswith("license:")
                            ),
                            "Unknown",
                        )

                        # Extract additional information
                        tags = model.get("tags", [])
                        pipeline_tags = [
                            tag for tag in tags if tag.startswith("pipeline_tag:")
                        ]
                        pipeline_tasks = [tag.split(":")[1] for tag in pipeline_tags]

                        all_models.append(
                            {
                                "name": model_id,
                                "url": f"https://huggingface.co/{model_id}",
                                "last_modified": last_modified.strftime(
                                    "%Y-%m-%d %H:%M:%S"
                                ),
                                "downloads": downloads,
                                "license": license,
                                "likes": likes,
                                "tags": tags,
                                "pipeline_tasks": pipeline_tasks,
                            }
                        )

                        if len(all_models) >= max_results:
                            print(
                                f"\nReached maximum number of results ({max_results}). Stopping search."
                            )
                            return all_models

                    print(
                        f"Processed {total_processed} models. Matching models: {len(all_models)}"
                    )

                    if next_cursor:
                        new_params = params.copy()
                        new_params["cursor"] = next_cursor
                        tasks.append(
                            asyncio.create_task(
                                fetch_models(session, base_url, headers, new_params)
                            )
                        )
                    elif not tasks:
                        print("No more pages to process.")

                except Exception as e:
                    print(f"Error processing task: {str(e)}")
                    print(f"Error details: {type(e).__name__}, {e.args}")

    return all_models


async def main():
    token = os.getenv("HUGGINGFACE_TOKEN")
    if not token:
        raise ValueError("Please set the HUGGINGFACE_TOKEN environment variable.")

    last_days = 90
    batch = 300
    max_results = 100
    min_downloads = 2000
    min_likes = 20
    concurrency = 10
    licenses = [
        "apache-2.0",
        "mit",
        "bsd-3-clause",
        "bsd-2-clause",
        "cc-by",
        "cc-by-sa",
        "openrail",
        "bigscience-bloom-rail-1.0",
    ]
    exclude_words = [
        "test",
        "demo",
        "nsfw",
        "gguf",
        "awq",
        "exl2",
        "gptq",
        "bnb",
        "Gradient",
        "fp8",
        "int4",
    ]

    models = await get_models(
        token,
        last_days,
        batch,
        max_results,
        min_downloads,
        min_likes,
        concurrency,
        licenses,
        exclude_words,
    )

    print(f"\nFound {len(models)} unique models matching all criteria:")
    for model in models:
        print(f"Name: {model['name']}")
        print(f"URL: {model['url']}")
        print(f"Last Modified: {model['last_modified']}")
        print(f"License: {model['license']}")
        print(f"Downloads: {model['downloads']}")
        print(f"Likes: {model['likes']}")
        print(f"Pipeline Tasks: {', '.join(model['pipeline_tasks'])}")
        print(f"Tags: {', '.join(model['tags'])}")
        print("---")


if __name__ == "__main__":
    asyncio.run(main())
